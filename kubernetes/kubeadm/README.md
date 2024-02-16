Install Kubernetes with kubeadm
--

This script will create a control plane and worker node using the latest version of Kubernetes.  The install is done via ```kubeadm```.  
  
Testing
--

This was tested with an Amazon Machine Image (AMI) running ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20231207.  
  
Pre-Installation
--

1) The hosts to install should be running and accessible via ssh.  Currently the scripts are written for one control plane and one worker node.  If you would like to expand this submit a PR.  
2) To automate, use ssh-add to load your ssh keys.  If you don't want to worry about host keys then set ```StrictHostKeyChecking no``` in your ssh client.  
3) Ensure all hosts can talk to each other and that they allow the necessary traffic.  I just opened up all traffic between the hosts in the security group, but if you want to restrict to specific ports you can use [this](https://kubernetes.io/docs/reference/networking/ports-and-protocols/) as a reference.  
  
Files
--
  
1) create_cluster.sh - installs the control plan and currently one worker node  
2) install_control_plane.sh - code to install control plane and create the worker node config  
  
Usage
-- 
  
```  
sh create_cluster.sh <ip_of_control_plane> <ip_of_worker_node>  
```  