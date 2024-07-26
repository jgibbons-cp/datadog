Application Tracing - Kubernetes
--

Let’s install an application  
  
1) Go to the application directory  
  
```  
datadog/kubernetes/lab/application/  
```  
  
2) There is a very basic Java application here.  Let’s run it, but from a different namespace:  
  

```
kubectl create ns application && kubectl config set-context --current --namespace=application  
```  
  
3) It has rum - we won’t set that up now.  This secret will allow us to launch error free, but for rum add a token/appid from your org.  Create the secret:  
  
```  
kubectl create secret generic dd-rum-tokens --from-literal CLIENT_TOKEN=TOKEN --from-literal APPLICATION_ID=APPID  
```  
  
4) Apply the manifests:  
  
```  
kubectl apply -f app-java.yaml -f mysql_ja.yaml  
```  
    
5) What is running?  Let’s hit it:  
  
```  
kubectl port-forward deploy/app-java 33333:8080  
```  
  
6) In a browser navigate to http://localhost:33333/app-java-0.0.1-SNAPSHOT/  
  
Let’s look at traces.  Why are we seeing what we are seeing?  
  
7) How do we add tracing?  
  
There are multiple ways we can but we will only cover three:  
  
* Admission controller - apply the manifest and restart the application:  
  
```  
kubectl config set-context --current --namespace=application  
kubectl apply -f datadog/kubernetes/lab/application/app-java-ac-trace.yaml  
kubectl get pod  
kubectl delete po <app-java-pod>  
kubectl port-forward deploy/app-java 33333:8080  
```  
  
In a browser navigate to http://localhost:33333/app-java-0.0.1-SNAPSHOT/  
  
* Single-step instrumentation - reapply the non-admission controller application  
  
```  
kubectl delete -f datadog/kubernetes/lab/application/app-java-ac-trace.yaml  
```  

Edit your agent manifest at ```datadog/kubernetes/lab/datadog-agent-all.yaml by adding the following to the apm section.  Below:    
  
```  
    apm:  
      enabled: true  
```  
  
add (so the whole thing looks like this - don't put the lines above in twice):  
    
```  
    apm:  
      enabled: true  
      instrumentation:  
        enabled: true  
        libVersions:  
          java: "v1.37.1"  
```  

Apply the new agent configuration:  
  
```  
kubectl apply -f datadog/kubernetes/lab/datadog-agent-all.yaml -n datadog
kubectl apply -f datadog/kubernetes/lab/application/app-java.yaml  
kubectl port-forward deploy/app-java 33333:8080  
```  

In a browser navigate to http://localhost:33333/app-java-0.0.1-SNAPSHOT/
      
* OTEL - we will not cover this in practice today.  Why would we use it?  It is a ds with a configmap for our exporter or using our agent with otlp listener and the OTEL support in the agent.    
