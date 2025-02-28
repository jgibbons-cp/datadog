Install Kubernetes with kubeadm
--

This script will create a control plane and worker node(s) using a stable version of Kubernetes.  The install is done via ```kubeadm```.  The default ```cri``` is ```containerd``` however ```dockerd``` and ```cri_o``` are also supported.  Currently the only pod network supported is ```weaveworks```.
  
Testing
--

This was tested with an Amazon Machine Image (AMI) ID ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20250115.  
  
Pre-Installation - no automation
--

1) The hosts to install should be running and accessible via ssh.  
2) To automate, use ssh-add to load your ssh key.  If you don't want to worry about host keys then set ```StrictHostKeyChecking no``` in your ssh client.  
3) Ensure all hosts can talk to each other and that they allow the necessary traffic.  I just opened up all traffic between the host IPs in the security group, but if you want to restrict to specific ports you can use [this](https://kubernetes.io/docs/reference/networking/ports-and-protocols/) as a reference.  
  
Pre-Installation - automated with AWS
--
  
This automates bringing up/down the infrastructure and the cluster.  
  
Variables:  
  
- install_control_plane.sh - Container runtime: ```cri``` - default is an empty string which installs containerd.  For the dockerd runtime set to ```dockerd```, and 
```cri_o``` for cri-o. 
- setup.sh - AWS Launch template: ```launch_template_id``` sets the EC2 template with vm size, ssh key etc.  
- setup.sh - Number of nodes (control plane plus optional worker(s)): ```node_count``` defaults to 2  
- functions.sh - Tags: key value pair to get security group and VMs  
    - ```tag_key - default: cluster```  
    - ```tag_value - default: kubeadm```  
- functions.sh - AWS region: ```region``` in which the infrastructure is located.  Defaults to ```us-west-2```  
- functions.sh - AWS credential profile: ```profile``` Defaults to ```default```  
- install_control_plane.sh - Controle Plane IP: ```public_cp_endpoint``` defaults to 1 which is public, set to 0 for private.  
  
Files
--
  
1) setup.sh - bring up infrastructure and kick-off cluster creation.  
2) create_cluster.sh - installs the control plane and, optionally, worker node(s).  
3) install_control_plane.sh - code to install control plane and create the worker node config  
4) functions.sh - shared functions.  
5) destroy.sh - tear down cluster and infrastructure.  
  
Usage
-- 

Manual:  
  
- Up:  
  
```  
sh create_cluster.sh <ip_of_control_plane> <optional ip_of_worker_node(s)>  
```  
  
- Down: terminate EC2 instances  
  
Automated up:  
  
1) Configure variables noted above  
2) ```sh setup.sh```  
  
Automated down:  
  
1) ```sh destroy.sh```  
