#!/bin/bash

control_plane=$1
worker_node_1=$2

if [ -z ${control_plane} ]; then echo "control_plane ip is not set... exiting...\n"; fi
if [ -z ${worker_node_1} ]; then echo "worker_node_1 ip is not set... exiting...\n"; fi

echo "pushing control plane install code up to node....\n" && \
scp install_control_plane.sh ubuntu@$control_plane:~/ && \

echo "installing control plane...\n"
ssh ubuntu@$control_plane "sh ~/install_control_plane.sh" && \

echo "pulling worker node code...\n"
scp ubuntu@$control_plane:~/install_cluster_worker_node.sh . && \

echo "pushing worker node code to worker node...\n"
scp install_cluster_worker_node.sh ubuntu@$worker_node_1:~/ && \

echo "installing worker node...\n"
ssh ubuntu@$worker_node_1 "sudo sh ~/install_cluster_worker_node.sh"

echo "\nUsage: ssh ubuntu@$control_plane to use kubectl...\n"

exit 0
