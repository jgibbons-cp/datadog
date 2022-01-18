Multiple Endpoints - Datadog Agent
--

Virtual Machine
--

Configure the Datadog agent:  

- ```sudo vi /etc/datadog/agent/datadog.yaml```  

- Add the following:  

```  
additional_endpoints:  
  #for US prod 1 or add another endpoint  
  "http://app.datadoghq.com":  
  - <api_key>  
```  

To check the status run:  

```  
sudo datadog-agent status  
```  

and you should see something like this:  

```  
API Keys status  
  ===============  
    API key ending with xxxxx: API Key valid  
    API key ending with xxxxx: API Key valid  

==========  
Endpoints  
==========  
  http://app.datadoghq.com - API Key ending with:  
      - xxxxx  
  https://app.datadoghq.com - API Key ending with:  
      - xxxxx  
```    

Kubernetes  
--

This is done with an environment variable called ```DD_ADDITIONAL_ENDPOINTS```  

Create a secret so you don't expose your API key in the helm chart.  

```  
#or a different endpoint as app.datadoghq.com is US1 prod  
kubectl create secret generic dd-additional-endpoints --from-literal DD_ADDITIONAL_ENDPOINTS='{"http://app.datadoghq.com":["API-KEY"]}'  
```  

In ```values.yaml``` add the secret ref to the agent envFrom section:  

```  
# datadog.envFrom -- Set environment variables for all Agents directly from configMaps and/or secrets  
## envFrom to pass configmaps or secrets as environment  
envFrom:  
  - secretRef:  
      name: dd-additional-endpoints  
```  

To check the status run:  

```  
kubectl exec -it POD agent status  
```  

and you will see something similar to the agent check above.  

A few more endpoints tested here on Kubernetes:  

Processes and Live Container View
-

Enable processes and process collection in the agent in the values file:  

```  
## Enable process agent and provide custom configs  
processAgent:  
  # datadog.processAgent.enabled -- Set this to true to enable live process monitoring agent  
  ## Note: /etc/passwd is automatically mounted to allow username resolution.  
  ## ref: https://docs.datadoghq.com/graphing/infrastructure/process/#kubernetes-daemonset  
  enabled: true  

  # datadog.processAgent.processCollection -- Set this to true to enable process collection in process monitoring agent  
  ## Requires processAgent.enabled to be set to true to have any effect  
  processCollection: true  
```  

Then add the additional endpoints as secrets, then to the values file in the same
section as the dd-additional-endpoint documented above as environment variables:  

```    
$ kubectl create secret generic dd-process-additional-endpoints --from-literal DD_PROCESS_ADDITIONAL_ENDPOINTS='{"https://process.datadoghq.com":["API-KEY"]}'  
$ kubectl create secret generic dd-orchestrator-additional-endpoints --from-literal DD_ORCHESTRATOR_ADDITIONAL_ENDPOINTS='{"https://orchestrator.datadoghq.com":["API-KEY"]}'  
```  

```  
- secretRef:  
    name: dd-process-additional-endpoints  
- secretRef:  
    name: dd-orchestrator-additional-endpoints  
```  

This will give you process views, live containers and pods.  I am not seeing nodes,
clusters etc. in the live container view.  I will need to look at that, but this
 gives the base idea.  
