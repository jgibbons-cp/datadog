DaemonSet All Features - Linux: Metrics Logs APM Processes NPM Security
--

Create the secret for the agent getting your keys from
[here](https://app.datadoghq.com/organization-settings/users).

```  
sudo kubectl create secret generic datadog-agent --from-literal api-key=<api-key> --from-literal app-key=<app-key>
```  

Create RBAC  

```  
kubectl apply -f "https://raw.githubusercontent.com/DataDog/datadog-agent/master/Dockerfiles/manifests/rbac/clusterrole.yaml" && kubectl apply -f "https://raw.githubusercontent.com/DataDog/datadog-agent/master/Dockerfiles/manifests/rbac/serviceaccount.yaml" && kubectl apply -f "https://raw.githubusercontent.com/DataDog/datadog-agent/master/Dockerfiles/manifests/rbac/clusterrolebinding.yaml"  
```  

Change DD_CLUSTER_NAME from example to what you want it to be in the manifest  

Apply the manifest  

```  
kubectl create -f datadog-agent-all-features.yaml  
```  

Apply the Kubernetes State Metrics  

```  
$ git clone https://github.com/kubernetes/kube-state-metrics.git  
$ cd kube-state-metrics/examples/  
$ kubectl apply -f standard  
```  
