Configure Cluster Agent
--

Create the secret for the clusteragent  

```  
kubectl create secret generic datadog-agent-cluster-agent --from-literal=token='<32-chars>' --namespace="default"  
```  

Go to the directory with the agent features you want in your cluster.  
