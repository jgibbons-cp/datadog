#!/bin/bash

# check if node is tainted
# parameters TOKEN
is_node_tainted(){
  # is node tainted with datadog taints?
  node_metadata=$(curl -k -H "Authorization: Bearer $1" \
    https://$KUBE_API_SERVER/api/v1/nodes/$NODE_NAME)
  taint_data=$(echo $node_metadata | \
    grep "{ \"key\": \"datadog\", \"effect\": \"NoSchedule\" }")

  if [ "$?" -ne "0" ]; then
    echo "Node $NODE_NAME is not tainted need to taint it with NoSchedule and NoExecute" >> $LOG
    return 1
  else
    echo "Node $NODE_NAME is tainted, getting pod info" >> $LOG
    return 0
  fi
}

# check if the port is listening
# parameters 
# service IP
# service port
datadog_connection_check(){
  agent_listening=1
  while [ "$agent_listening" -ne "0" ]; do
    curl -k $1:$2
    if [ "$?" -eq "0" ]; then
      agent_listening=0
    fi
  done

  # don't do anything with this now
  return $agent_listening
}

# remove datadog taints
# Parameter TOKEN
untaint_node(){
  echo "Untainting node..." >> $LOG

  # get taints
  node_metadata=$(curl -k -H "Authorization: Bearer $1" \
    https://$KUBE_API_SERVER/api/v1/nodes/$NODE_NAME \
    | jq .spec.taints)

  len=$(echo $node_metadata | jq 'length')

  i=$(($len-1))
  while [ "$i" -ge "0" ];
  do
    taint=$(echo "$node_metadata" | jq -r --argjson idx "$i" '.[$idx]')

    # delete any datadog related taints from the array
    echo $taint | grep datadog
    if [ "$?" -eq "0" ]; then
      node_metadata=$(echo "$node_metadata" |  jq -r --argjson idx "$i" 'del(.[$idx])')
    fi
    i=$((i-1))
  done

  # apply the taint array
  taint_array=$(cat <<EOF
{"spec":{"taints":$node_metadata}}
EOF
)

  curl -k -X PATCH \
    -H "Content-Type: application/strategic-merge-patch+json" \
    -H "Authorization: Bearer $1" \
    -d "$taint_array" \
    https://$KUBE_API_SERVER/api/v1/nodes/$NODE_NAME
}

# taint the node so nothing can be scheduled and pods are evicted
# Use-case: reboot of a node, not pod lifecycle
# Parameters: TOKEN
taint_node(){
  echo "Tainting node..." >> $LOG

  node_metadata=$(curl -k -H "Authorization: Bearer $1" \
    https://$KUBE_API_SERVER/api/v1/nodes/$NODE_NAME \
    | jq .spec.taints)

  node_metadata=$(echo $node_metadata | jq '. += [{"key": "datadog", "effect": "NoSchedule"}]')
  node_metadata=$(echo $node_metadata | jq '. += [{"key": "datadog", "effect": "NoExecute"}]')

  # apply the taint array
  taint_array=$(cat <<EOF
{"spec":{"taints":$node_metadata}}
EOF
)
  curl -k -X PATCH \
    -H "Content-Type: application/merge-patch+json" \
    -H "Authorization: Bearer $1" \
    -d "$taint_array" \
    https://$KUBE_API_SERVER/api/v1/nodes/$NODE_NAME

  return
}

# delete kyverno policy to block all deployments in certain ns's
delete_kyverno_block(){
  curl -k -H "Authorization: Bearer ${TOKEN}" \
    https:/$KUBE_API_SERVER/apis/kyverno.io/v1/clusterpolicies/deny-deployment
  
  if [ "$?" -eq "0" ]; then
    curl -k -X DELETE \
      "https://$KUBE_API_SERVER/apis/kyverno.io/v1/clusterpolicies/deny-deployment" \
      --header "Authorization: Bearer $TOKEN" \
      --header "Content-Type: application/json" \
      --data-binary \
      '{"apiVersion":"v1","kind":"DeleteOptions","propagationPolicy":"Foreground"}'
  fi 

  return 0
}

# get the datadog service ip, so you can grab if dns not working atm
# Parameter
# service name
get_datadog_service_ip(){
  service_ip=$(curl -k -H "Authorization: Bearer ${TOKEN}" \
    https:/$KUBERNETES_SERVICE_HOST/api/v1/namespaces/datadog/services/$1 | \
    jq -r '.spec.clusterIP')
  echo $service_ip
}

# main application
main(){
  LOG="app.log"
  
  # assign default IP to talk to api server dns or not
  KUBE_API_SERVER=$KUBERNETES_SERVICE_HOST

  # get sa token
  TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

  # check if the node has datadog taints
  if [ "$TAINTS" = "0" ]; then
    is_node_tainted $TOKEN
    if [ $? -ne 0 ]; then
      taint_node $TOKEN
    fi
  fi 

  dd_agent_running=1
  dd_cluster_agent_running=1

  endpoint="/api/v1/namespaces/datadog/pods"

  echo "About to enter check for running agent.  dd_agent_running is $dd_agent_running and \
dd_cluster_agent_running is $dd_cluster_agent_running" >> $LOG

  # if the agent is not running keep checking until it is
  while [ "$dd_agent_running" -ne "0" ] || [ "$dd_cluster_agent_running" -ne "0" ]; do
    echo "Inside agent check." >> $LOG

    pods_with_status=$(curl -k -H "Authorization: Bearer ${TOKEN}" \
        https:/$KUBE_API_SERVER$endpoint?fieldSelector=spec.nodeName=$NODE_NAME   \
        | jq '.items[] | .metadata.name + " " + .status.phase')
    echo $pods_with_status | grep "dd-agent-datadog" | grep -v "cluster" | grep "Running"
    dd_agent_running=$?

    if [ "$dd_agent_running=$?" -eq "0" ]; then
      pods_with_status=$(curl -k -H "Authorization: Bearer ${TOKEN}" \
          https:/$KUBE_API_SERVER$endpoint   \
          | jq -r '.items[] | .metadata.name as $podName | .status.containerStatuses[] | "\($podName) - \(.name): Ready=\(.ready), State=\(.state)\\n"')
      echo $pods_with_status | grep "dd-agent-datadog" \
        | grep Ready=true
    fi 
    dd_agent_running=$?

    pods_with_status=$(curl -k -H "Authorization: Bearer ${TOKEN}" \
        https:/$KUBE_API_SERVER$endpoint   \
        | jq '.items[] | .metadata.name + " " + .status.phase + "\\\n"')
    echo $pods_with_status | grep "dd-agent-datadog-cluster-agent" \
        | grep "Running"
    dd_cluster_agent_running=$?

    if [ "$dd_cluster_agent_running" -eq "0" ]; then
      pods_with_status=$(curl -k -H "Authorization: Bearer ${TOKEN}" \
          https:/$KUBE_API_SERVER$endpoint   \
          | jq -r '.items[] | .metadata.name as $podName | .status.containerStatuses[] | "\($podName) - \(.name): Ready=\(.ready), State=\(.state)\\n"')
      echo $pods_with_status | grep "dd-agent-datadog-cluster-agent" \
        | grep Ready=true
      dd_cluster_agent_running=$?
      echo $dd_cluster_agent_running
    fi

    interval=5
    if [ "$dd_agent_running" -ne "0" ] || [ "$dd_cluster_agent_running" -ne "0" ]; then
      echo "Agents are not running." >> $LOG
      sleep $interval
    else
      # need it to be listening to continue
      admission_controller_port="443"
      cluster_agent_port="5005"
      agent_trace_port="8126"
      agent_service_name="dd-agent-datadog"
      cluster_agent_service_name="dd-agent-datadog-cluster-agent"
      admission_controller_service_name="dd-\
agent-datadog-cluster-agent-admission-controller"

      ip=$(get_datadog_service_ip $admission_controller_service_name)
      datadog_connection_check $ip $admission_controller_port

      ip=$(get_datadog_service_ip $cluster_agent_service_name)
      datadog_connection_check $ip $cluster_agent_port

      ip=$(get_datadog_service_ip $agent_service_name)
      datadog_connection_check $ip $agent_trace_port

      # get rid of taints to schedule pods
      if [ "$TAINTS" = "0" ]; then
        untaint_node $TOKEN
      fi
      if [ "$KYVERNO" = "0" ]; then
        delete_kyverno_block
      fi
    fi
  done

  # need this to be a ds so lightweight process after check
  while true; do
    tail -f /dev/null
  done
}

main
