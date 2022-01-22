Creating a Rancher Instance
--

[Rancher](https://rancher.com/) provides a UI and management capabilities on top
of a local cluster (e.g. on an EC2 instance).  It also adds the ability to pull
in downstream clusters (e.g. on-prem, EKS, AKS) as well as create clusters from
the UI.  

Here is a base example to create an instance on a single EC2 host with a local
Kubernetes single node cluster.  Everything done using an Ubuntu Server 20.04
LTS (HVM) instance.  

1) Launch an EC2 instance in AWS and open the ports from your laptop in the
security group (t2medium seems to be powerful enough)  

2) Prepare the host  

```  
#update  
sudo apt-get update  
#install docker  
sudo apt-get install docker.io  
#add group/user to group  
sudo groupadd docker  
sudo usermod -aG docker $USER  
#log in/out shell so you don't have to use sudo - if not use sudo  
#launch rancher  
docker run -d --restart=unless-stopped -p 81:80 -p 444:443 --privileged rancher/rancher:v2.6-head  
#get your container id  
docker container ls  
#get your bootstrap password  
docker logs <container_id> 2>&1 | grep "Bootstrap Password:"
```  

3) Go to UI  

```  
https://<ip_of_ec2_instance>:444  
```  

4) Proceed past the unsigned certificate warnings.  

5) Use your bootstrap password, then change your password and login.  

You now have a local Rancher instance with a one node Kubernetes cluster.  Go to
the hamburger menu on the top left then to local cluster.  If you have trouble
seeing your cluster refresh / may be the self-signed certificates.  You can also
add/create clusters from the UI.  

NOTE: In Apps and Marketplace there is a UI that installs the Datadog agent (NOTE:
it will require tolerations to install on the controlplane nodes normally but not
here).  We were able to get it to install with the UI, but it obbuscates everything
creates a difficult to manage values file.  We were not able to get live containers
working from the UI install and I kept getting ClusterRole errors.  There seems to
be an issue especially if you want live containers and the Core KubeStateMetrics.
I installed from the command line in the Rancher instance using helm and my own
values and all worked as expected.  

Have fun!  
