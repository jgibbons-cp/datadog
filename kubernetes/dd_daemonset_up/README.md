Datadog DaemonSet Up
--

Have you ever wanted to ensure a DaemonSet is running before deploying other pods?  I have heard 
that asked for in regards to the Datadog agent.  This idea was explored in the article [Kubernetes: Do not Schedule Pods until the Datadog Agent is Running](https://medium.com/@jenksgibbons/3bccd0f84a2e).  
  
Files:  
  
- Dockerfile: the file to build the container. 
- ds_up.sh: the script to monitor the agent and a) remove taints and/or b) remove a Kyverno
policy that blocks Deployments in some namespaces.  
- rbac.yaml: RBAC to call the needed resources from the Kube REST API.  
- dd-agent-running.yaml: manifest for the application that monitors if the Datadog agent 
is running using the script ds_up.sh.  
- dd-agent-with-tolerations.yaml: Datadog agent manifest with APM turned on using single-step 
instrumentation.  
- kyverno-deny-deployment.yaml: Kyverno policy to block Deployments outside of the namespaces 
kyverno, datadog and kube-system.  
  
Usage:  
  
- Create namespace for agent: ```k create ns datadog```  
- Create secret for agent: ```kubectl create secret generic datadog-secret --from-literal api-key=```[API-KEY](https://app.datadoghq.com/organization-settings/api-keys)``` --from-literal app-key=```[APP-KEY](https://app.datadoghq.com/organization-settings/application-keys)``` -n datadog```  
- Add helm repo: ```helm repo add datadog https://helm.datadoghq.com```  
- Update repo: ```helm repo update```  
- Install agent: ```helm upgrade --install -n datadog dd-agent -f dd-agent-with-tolerations.yaml datadog/datadog```  
- Apply manifest to monitor the agent deployment: ```k apply -f dd-agent-running.yaml```  By default
 the manifest is set to do nothing.  To remove taints set TAINTS to 0 and to remove the Kyverno policy set KYVERNO to 0.  

- Use-case: monitor if the agent is up on a newly created cluster with default taints, ```datadog:NoSchedule```  This ensures the agent is up before allowing scheduling.  It also allows
for reboots by applying ```datadog:NoSchedule``` and ```datadog:NoExecute```  This does not make much sense to me.  
- Use-case: monitor if the agent is up so applications are not deployed until the admission controller
is up to ensure applications don't need to be restarted for single-step APM.  