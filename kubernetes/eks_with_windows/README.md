Create an EKS Cluster with a Windows Worker Node
--

The following steps will guide you on how to create an EKS Cluster on AWS with
a Windows worker node.  It will also guide you in how to deploy the Datadog K8
agent using helm on the master node as well as the Linix and Windows worker
nodes.  

This is all taken out of AWS documentation which we will note in here.  I will
not cover information about the IAM role that is needed, but that can be found
in AWS documentation for EKS.  

This will be done via eksctl which is needed for adding a Windows node to the
cluster after creation.  

The initial steps are taken from the AWS documentation entitled
[Getting Started with Amazon EKS - eksctl](https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html)  

1) Create a key-pair in the <region> desired with the <key_name> desired.

```
aws ec2 create-key-pair --region <region> --key-name <key_name>
```
2) Create an EKS cluster - the control plane must be run on Linux so the first
step is to create a cluster, then you will add a Windows node to it later.  To
enable ssh access look at the eksctl options as this creates a private cluster.
  I will look into this when I have time as I don't need to ssh now.  
```
eksctl create cluster \
--name <cluster_name> \
--region <region> \
--with-oidc \
--ssh-access \
--ssh-public-key <key_name>
```

3) Confirm the cluster is up.  

```
kubectl get nodes
```

which should return the stack  

```
NAME                                          STATUS   ROLES    AGE   VERSION
ip-xxxx.us-west-1.compute.internal   Ready    <none>   67s   v1.20.10-eks-3bcdcd
ip-xxxx.us-west-1.compute.internal   Ready    <none>   69s   v1.20.10-eks-3bcdcd
```

4) Enable Windows support - from the AWS documentation
[Enabling Window Support](https://docs.aws.amazon.com/eks/latest/userguide/windows-support.html)  

```
eksctl utils install-vpc-controllers --cluster <cluster_name> --region <region>
 --approve
```  

5) Add a Windows worker node to the cluster - from
[Launching self-managed Windows nodes](https://docs.aws.amazon.com/eks/latest/userguide/launch-windows-workers.html)  

```
eksctl create nodegroup \
  --region <region> \
  --cluster <cluster_name> \
  --name <name> \
  --node-type <t2.large> \
  --nodes <3> \
  --nodes-min <1> \
  --nodes-max <4> \
  --node-ami-family WindowsServer2019FullContainer
  --managed=false
```  

Confirm the node is in the stack  

```
kubectl get nodes -o wide
```

The results should look like this:  

```
NAME                                           STATUS   ROLES    AGE    VERSION               INTERNAL-IP      EXTERNAL-IP     OS-IMAGE                         KERNEL-VERSION                CONTAINER-RUNTIME
ip-xxxx.us-west-1.compute.internal   Ready    <none>   109s   v1.20.10-eks-3bcdcd   192.168.44.206   x.x.x.x   Windows Server 2019 Datacenter   10.0.17763.2237               docker://20.10.7
ip-xxxx.us-west-1.compute.internal    Ready    <none>   26m    v1.20.10-eks-3bcdcd   192.168.48.73    x.x.x.x   Amazon Linux 2                   5.4.149-73.259.amzn2.x86_64   docker://20.10.7
ip-xxxx.us-west-1.compute.internal    Ready    <none>   26m    v1.20.10-eks-3bcdcd   192.168.93.37    x.x.x.x   Amazon Linux 2                   5.4.149-73.259.amzn2.x86_64   docker://20.10.7
```

6) The agent documentation for Datadog is from this
[documentation](https://docs.datadoghq.com/agent/troubleshooting/windows_containers/)  

To avoid installing kube-state-metrics twice (as there will need to be two
  helm installs - one for Linux and one for Windows) taint the Window node.

```
kubectl taint node <node> node.kubernetes.io/os=windows:NoSchedule
```  

And then you should see this:  

```
kubectl describe node <node> | grep -i taint
Taints:             node.kubernetes.io/os=windows:NoSchedule
```  

7)  Create your app and api key secrets:  

```
kubectl create secret generic datadog-agent --from-literal api-key=<key> --from-literal app-key=<key>
```

8)  Deploy the Datadog agent using
[helm](https://docs.datadoghq.com/agent/kubernetes/?tab=helm):  

a) First for Linux:  

Set your cluster name in the values file:  
```  
clusterName:  <cluster_name>  
portEnabled: true #under apm  
```  

Deploy:  

```
helm install dd-agent -f <values_yaml> datadog/datadog --set targetSystem=linux  
```
You should see something like this:  

```
kubectl get all | grep dd
pod/dd-agent-datadog-9ptvx                            5/5     Running   0          70s
pod/dd-agent-datadog-bldvh                            5/5     Running   0          70s
pod/dd-agent-datadog-cluster-agent-5b6ccc89c4-sqlhg   1/1     Running   0          70s
pod/dd-agent-kube-state-metrics-7f4f4f4dd5-dbpvz      1/1     Running   0          70s
service/dd-agent-datadog-cluster-agent   ClusterIP   x.x.x.x    <none>        5005/TCP   70s
service/dd-agent-kube-state-metrics      ClusterIP   x.x.x.x   <none>        8080/TCP   70s
daemonset.apps/dd-agent-datadog   2         2         2       2            2           kubernetes.io/os=linux   71s
deployment.apps/dd-agent-datadog-cluster-agent   1/1     1            1           71s
deployment.apps/dd-agent-kube-state-metrics      1/1     1            1           71s
replicaset.apps/dd-agent-datadog-cluster-agent-5b6ccc89c4   1         1         1       71s
replicaset.apps/dd-agent-kube-state-metrics-7f4f4f4dd5      1         1         1       71s
```  

b) Next for Windows:  

Set your cluster name in the values file:  
```  
clusterName:  <cluster_name>  
kubeStateMetricsEnabled: false  #so don't install twice
portEnabled: true #under apm  
existingClusterAgent:  
  # existingClusterAgent.join -- set this to true if you want the agents deployed by this chart to  
  # connect to a Cluster Agent deployed independently  
  join: true  
```  

```  
helm install dd-agent -f <values_file> datadog/datadog --set targetSystem=windows  
```

You should see something like this:  

```
kubectl get all | grep win  
pod/dd-agent-win-datadog-kcfgx                        3/3     Running   0          81s  
daemonset.apps/dd-agent-win-datadog   1         1         1       1            1           kubernetes.io/os=windows   82s  
```  

OK, Datadog deployed.  

Might as well look at a quick Windows deploy.  

9) Deploy IIS  

Deploy the pod using iis.yaml  

```  
kubectl create -f iis.yaml  
```

NOTE: to schedule it on the/a windows node you will need to note the toleration
and nodeSelector in the yaml.  

10) Expose the deployment so we can hit it.  

```  
kubectl expose deploy iis --name iis --port=80 --target-port=80 --type=LoadBalancer
```  

You should see something like this:  

```
kubectl get svc | grep iis
iis                              LoadBalancer   <ip>   <lb_name>.<region>.elb.amazonaws.com   80:31346/TCP   49m
```

11) Open up the loadbalancer in AWS to allow 80 inbound from your host  

12)  Hit the app  

```  
<load_balancer> #on port 80 so that should do it  
```  

Have fun!  

When you are done.... delete the cluster.

```
eksctl delete cluster --name <name> --region <region>
```  
