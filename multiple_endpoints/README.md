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
