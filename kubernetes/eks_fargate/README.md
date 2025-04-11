Datadog <> EKS on Fargate Configuration  
---

Configuration  
--

The following outlines how to collect data from your applications running in AWS EKS Fargate.

1) Install the agent (example here uses helm)  
2) Bind the clusterrole datadog-agent to the service account used in the deployment. If you use 
the default service account, create a new one called datadog-agent and bind it to the clusterrole.  
3) Set the service account in your deployment to the one from step 2, either datadog-agent or another 
custom one that is not the default.  
4) If you have not labeled your namespace for Datadog agent injection, then label your pods in the 
deployment with:  
  
```  
agent.datadoghq.com/sidecar: fargate  
```  
5) Deploy

Agent Install  
--  
NOTE: the values file provided here is bare minimum.  The options to add features are in the default
which can be found [here](https://github.com/DataDog/helm-charts/blob/main/charts/datadog/values.yaml).  
  
```  
$ kubectl create secret generic datadog-secret -n <your_agent_namespace> --from-literal api-key=<YOUR_DATADOG_API_KEY> --from-literal app-key=<YOUR_DATADOG_APP_KEY>  
  
$ kubectl create secret generic datadog-secret -n <your_application_namespace> --from-literal api-key=<YOUR_DATADOG_API_KEY> --from-literal app-key=<YOUR_DATADOG_APP_KEY>  
  
$ helm install datadog-agent -f values.yaml datadog/datadog -n <your_agent_namespace>  
```  
  
This will install the service accounts as well as the cluster agent in the namespace you choose.  

Application Namespace RBAC  
---
The namespace(s) you choose to install applications, will need RBAC for Datadog agent functionality. So, bind your service account to the clusterrole created when the agent deployed.  The service account can be called anything, but you can use datadog-agent if you are not using a custom one for the deployment. If you are using a custom service account, bind that to the clusterrole datadog-agent for any namespace where you want to use Datadog.  
  
Add the Service Account to your Deployment if not there
---
Whatever service account you bound to the datadog-agent clusterrole, add it to the pod spec of your deployment.  
  
```  
serviceAccountName: <your_service_account>  
```    
  
Setup Agent Injection
---
If you have not added selectors for Datadog agent injection in your agent config, then label your pods in the 
deployment with:  
  
```  
agent.datadoghq.com/sidecar: fargate  
```  
  
Deploy your Application  