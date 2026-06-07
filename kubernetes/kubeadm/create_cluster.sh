#!/bin/bash
source ./functions.sh

# can solve for key not loaded with ssh-add
PEM="-i /Users/jenks.gibbons/Downloads/dd_aws_us_west_1.pem"
SSH_FLAGS="-o IdentitiesOnly=yes -o $PEM"

# use first IP as control plane
control_plane=$1

if [ -z ${control_plane} ]; then 
  echo "control_plane ip is not set... need at least that... \
exiting...\n" && exit 1;
fi

echo "pushing control plane install code up to node....\n"

return_code=255
counter=0

# kill all if can't get into a node
while [[ "$return_code" != [0] ]]
do
  sleep 5
  echo "attempting ssh connection...\n"
  scp $SSH_FLAGS install_control_plane.sh ubuntu@$control_plane:~/
  # TODO to add taints by default
  #scp $SSH_FLAGS kubelet_patch.yaml install_control_plane.sh ubuntu@$control_plane:~/
  return_code=$?
  
  if [ $counter -eq 3 ]; then
    echo $counter
    echo "Can't connect to host $control_plane.  \
Exiting and deleting infra...\n"
    sh destroy.sh
    exit -1
  fi
  
  let "counter+=1"
done

echo "installing control plane...\n" && \
ssh $SSH_FLAGS ubuntu@$control_plane "sh ~/install_control_plane.sh"

echo "pulling worker node code...\n" && \
scp $SSH_FLAGS ubuntu@$control_plane:~/install_cluster_worker_node.sh .

#create all worker nodes
for var in "$@"
do  
  if test -f /etc/containerd/config.toml; then
    # set to use with Longhorn for dynamic volume creation
    sudo sed -i 's/SystemdCgroup = true/SystemdCgroup = false/' /etc/containerd/config.toml
  fi
  echo "pushing worker node code to worker node...\n" && \
  scp $SSH_FLAGS install_cluster_worker_node.sh "ubuntu@${var}:~/" && \
   
  echo "installing worker node...\n"
  ssh $SSH_FLAGS "ubuntu@${var}" "sudo sh ~/install_cluster_worker_node.sh"
done

# wait for cilium and nodes to be ready
echo "\nwaiting for cluster to be ready...\n"
ret_val=0
while [ "$ret_val" -eq "0" ]; do 
  output=$(ssh ubuntu@$control_plane kubectl get nodes | grep Ready;)
  echo $output | grep NotReady > /dev/null
  ret_val=$?
  sleep 15
  ssh ubuntu@$control_plane kubectl get nodes
  echo ""
done

echo "\nUsage: 'ssh ubuntu@$control_plane' to use kubectl. If the control plane \
has a public IP then 'scp ubuntu@$control_plane:~/.kube/config . && export KUBECONFIG=$(pwd)/config'\n"

# clean up repo
rm -f install_cluster_worker_node.sh
exit 0
