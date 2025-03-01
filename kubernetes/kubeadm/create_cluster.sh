#!/bin/bash
source ./functions.sh

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
  scp install_control_plane.sh ubuntu@$control_plane:~/
  return_code=$?
  
  if [ $counter -eq 10 ]; then
    echo $counter
    echo "Can't connect to host $control_plane.  \
Exiting and deleting infra...\n"
    sh destroy.sh
    exit -1
  fi
  
  let "counter+=1"
done

echo "installing control plane...\n" && \
ssh ubuntu@$control_plane "sh ~/install_control_plane.sh"

echo "pulling worker node code...\n" && \
scp ubuntu@$control_plane:~/install_cluster_worker_node.sh . && \

#create all worker nodes
for var in "$@"
do  
  echo "pushing worker node code to worker node...\n" && \
  scp install_cluster_worker_node.sh "ubuntu@${var}:~/" && \
   
  echo "installing worker node...\n"
  ssh "ubuntu@${var}" "sudo sh ~/install_cluster_worker_node.sh"

  if [ "$?" -ne "0" ]; then
    echo "\nssh failed to host...\n"
  fi
done

echo "\nUsage: 'ssh ubuntu@$control_plane' to use kubectl. If the control plane \
has a public IP then 'scp ubuntu@$control_plane:~/.kube/config . && export KUBECONFIG=$(pwd)/config'\n"

# clean up repo
rm -f install_cluster_worker_node.sh
exit 0
