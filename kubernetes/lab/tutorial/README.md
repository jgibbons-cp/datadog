Tutorial from kubernetes.io
--

In this basic [tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/), we will review base Kubernetes functionality.  
  
1) Create a cluster - pull down this setup script (creates a minikube cluster with a [taint](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)).  Create the cluster:
  
```  
wget https://github.com/jgibbons-cp/datadog/blob/main/kubernetes/lab/setup.sh  
sh setup.sh  
```  
  
or  
  
```  
curl -O https://github.com/jgibbons-cp/datadog/blob/main/kubernetes/lab/setup.sh  
sh setup.sh  
```  
  
Look at the nodes:  
  
```  
kubectl get nodes -o wide  
```  
  
Declarative vs. [imperative](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/imperative-command/) commands  

```  
kubectl run nginx --image nginx  
# or [declarative](https://kubernetes.io/docs/concepts/workloads/pods/)    
```  
  
What are some benefits/drawbacks of each?  
  
Create a [deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) which provides declarative updates for Pods and ReplicaSets:  
  
```  
kubectl create deploy nginx --image nginx  
```  
  
This is going to give us a ReplicaSet:  
  
```  
kubectl get rs  
kubectl describe rs <rs_name>  
```  
  
How do you usually launch applications?  [Pod](https://kubernetes.io/docs/concepts/workloads/pods/), Deployment, [ReplicaSet](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/), [StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)  
  
How do you connect to applications?  [Services](https://kubernetes.io/docs/concepts/services-networking/service/)  
  
* [ClusterIP](https://kubernetes.io/docs/concepts/services-networking/service/#type-clusterip) - an internal service (e.g. Java application connects to mysql on <service>:3306)  
  
* [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport) - allows for external access to a NodePort (30000-32767) that maps to a container port.  For example, to connect to nginx might be 32222->443.  When using ports on the host make sure you firewall it appropriately.  
  
* [LoadBalancer](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer) - this is a public cloud service.  For example, nginx-ingress.  
  
* We are using minikkube so the easiest way to connect is to use a [port-forward](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/).  This forwards a local port to a port in an application (e.g. pod, deployment).  
  
```  
kubectl port-forward deploy/nginx 33333:80  
```  
  
In a browser (or curl in another terminal)  
  
```  
http://localhost:33333/  
```  
  
[Scale](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_scale/) the application:  
  
```  
kubectl scale deploy/nginx --replicas 2  
kubectl get pods  
```  
  
Will this persist?  
  
Descale the application  
  
```  
kubectl edit deploy nginx  
# Search for replicas and change 2 to 1  
```  

How many pods now?  

```  
kubectl get pods  
```  
  
Update the application.  What is the application and how is it packaged?  
  
```  
kubectl describe deploy nginx | grep -i image  
```  
  
Pods consist of 1 or more containers and containers are run from [images](https://hub.docker.com/_/nginx). Where are images served by default?  
  
Let’s pin it to a version rather than defaulting to latest.  Why is this a best practice?  
  
```  
kubectl set image deployment/nginx nginx=nginx:1.27.0  
```  
  
```  
kubectl describe deploy nginx | grep -i image  
```  
  
Will this persist?  Why?  
  
Get a manifest to persist  
  
```  
kubectl get deploy nginx -o yaml > nginx_deploy.yaml  
```  
  
This is a very basic, foundational tutorial of Kubernetes.  
