Create an Multi OS EKS Cluster, Deploy Datadog, Deploy IIS
--

The following steps from [here](https://eksctl.io/usage/windows-worker-nodes/) will guide you on how to create a multi-OS 
EKS Cluster.  It will also guide you in how to deploy the Datadog K8 agent using helm on the master node as well as the 
Linux and Windows worker nodes.  

Pre-Requisites
--

1) [Get](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html) eksctl
    
1) Create the cluster (change the values for nodes etc. if you want):  
  
```eksctl create cluster -f cluster.yaml```  

2) The following values files can be used. 
[Linux](https://github.com/jgibbons-cp/datadog/blob/main/kubernetes/aks_with_windows/values.yaml) 
[Windows](https://github.com/jgibbons-cp/datadog/blob/main/kubernetes/aks_with_windows/values_win.yaml)  
   
3)  Create your [app](https://app.datadoghq.com/organization-settings/application-keys) and 
[api](https://app.datadoghq.com/organization-settings/api-keys) key secrets:  
  
```  
kubectl create secret generic datadog-agent --from-literal api-key=<key> --from-literal app-key=<key>  
```  
  
8)  Deploy the Datadog agent using
[helm](https://docs.datadoghq.com/agent/kubernetes/?tab=helm):  

a) First for Linux:  

Set the following values:  
```  
clusterName: <cluster_name>  
tlsVerify: true
```  

Deploy:  

```
helm install dd-agent -f <values_yaml> datadog/datadog  
```
You should see something like this:  

```
NAME                                              READY   STATUS    RESTARTS   AGE  
dd-agent-datadog-67ktq                            5/5     Running   0          66s  
dd-agent-datadog-cluster-agent-69859cfd98-x8b8m   1/1     Running   0          66s  
dd-agent-datadog-nptd5                            5/5     Running   0          66s  
```  
  
b) Next for Windows:  
  
Set your cluster name in the values file:  
```  
clusterName:  <cluster_name>  
tlsVerify: true  
## dogstatsd configuration - how to configure since no hostPort?  need to look into
## need to remove network
## need to move metricsProvider I think
### FOR TRACING ON WINDOWS EKS ONLY - no hostPort support so need to use service ###
### add this to the bottom of the values_win.yaml
agents:
    # agents.localService.forceLocalServiceEnabled -- Force the creation of the internal traffic policy service to target the agent running on the local node.
    # By default, the internal traffic service is created only on Kubernetes 1.22+ where the feature became beta and enabled by default.
    # This option allows to force the creation of the internal traffic service on kubernetes 1.21 where the feature was alpha and required a feature gate to be explicitly enabled.
    forceLocalServiceEnabled: true
```  

```  
helm install dd-agent-win -f <values_file> datadog/datadog  
```

You should see something like this:  

```
NAME                                              READY   STATUS    RESTARTS   AGE
dd-agent-datadog-67ktq                            5/5     Running   0          3m36s
dd-agent-datadog-cluster-agent-69859cfd98-x8b8m   1/1     Running   0          3m36s
dd-agent-datadog-nptd5                            5/5     Running   0          3m36s
dd-agent-win-datadog-6qcnj                        3/3     Running   0          88s
```  
  
OK, Datadog deployed.  
  
Might as well look at a quick Windows deploy - or go to step 10 for a tracing example.  
  
9) Deploy IIS  
  
Deploy the pod using iis.yaml  
  
```  
kubectl create -f iis.yaml  
```  
  
NOTE: to schedule it on the/a windows node you will need to note the toleration
and nodeSelector in the yaml.  
  
10) Use [this](https://github.com/jgibbons-cp/datadog/blob/main/kubernetes/aspnet48_mvc_app/asp_dotnet_sample.yaml) 
as a base manifest.  

Change:  
```  
          - name: DD_AGENT_HOST  
            valueFrom:  
                fieldRef:  
                  fieldPath: status.hostIP  
 ```  
   
to  
  
```  
          - name: DD_AGENT_HOST  
            # <windows_datadog_agent_service_name>.<namespace>.svc.cluster.local  
            value: dd-agent-win-datadog.<namespace>.svc.cluster.local  
```  
    
Set <env>, <service>, and <env>  
  
Deploy  
```  
kubectl create -f sample.yaml  
```  
  
11) Expose the deployment with a port-forward.  
  
```  
kubectl port-forward deploy/iis 33333:80  
```  
  
13) Hit the app  
  
```  
http://localhost:33333  
```  
  
Have fun!  
  
When you are done.... delete the cluster.  
  
```  
eksctl delete cluster -f cluster.yaml  
```  
