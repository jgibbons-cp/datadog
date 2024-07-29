Application - Kubernetes
--

Let’s install an application  
  
- We will run a very basic Java application here, but from a different namespace:  
  
```
kubectl create ns application && kubectl config set-context --current --namespace=application  
```  
  
- It has RUM - let's make sure we have RUM setup in Datadog.  


- This secret will allow us to launch error free, but for rum add a token/appid from your org.  Create the secret:  
  
```  
kubectl create secret generic dd-rum-tokens --from-literal CLIENT_TOKEN=TOKEN --from-literal APPLICATION_ID=APPID  
```  
  
- Apply the manifests:  
  
```  
kubectl apply -f https://raw.githubusercontent.com/jgibbons-cp/datadog/main/kubernetes/lab/application/app-java.yaml \
  -f https://raw.githubusercontent.com/jgibbons-cp/datadog/main/kubernetes/lab/application/mysql_ja.yaml    
```  
    
- What is running?  Let’s hit it:  
  
```  
kubectl port-forward deploy/app-java 33333:8080  
```  
  
- In a browser navigate to http://localhost:33333/app-java-0.0.1-SNAPSHOT/  
  
Let’s look at [traces](https://app.datadoghq.com/apm/traces).  Why are we seeing what we are seeing?  
  
- How do we add tracing?  

Tracing
-
  
There are multiple ways; let's start with the admission controller.  
  
1) Admission controller - we applied the Java application with a URL.  We have no state.  What happens if we just edit the running YAML? Let's get a manifest.  
  
```  
kubectl get deploy app-java -o yaml > ry_app_java.yaml  
```  
  
Now we have a manifest.  We are going to add a [label](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) and an [annotation](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/)  
  
With the editor of your choice, open app_java.yaml  

We are going to add tracing using the following [documentation](https://docs.datadoghq.com/containers/cluster_agent/admission_controller/?tab=datadogoperator).  
  
Open ry_app_java.yaml  
  
In ```spec.template.annotations``` add  
  
```  
        admission.datadoghq.com/java-lib.version: "v1.37.1"  
```  
  
and in ```spec.template.labels``` add  
  
```  
        admission.datadoghq.com/enabled: "true"  
```  
  
Apply the change  
  
```
kubectl apply -f ry_app_java.yaml  
```  
  
If the pod does not go out of pending delete the running one ```k delete po <pod_name>```  
  
What did we just do?  If you look as the pod relaunched you would see this:  
  
```  
app-java-bb8dc9b89-rdmrm   0/1     Init:0/1   0          2s  
```  

What is that?  
  
Let's hit it  
  
```  
kubectl port-forward deploy/app-java 33333:8080  
```  
  
In a browser navigate to http://localhost:33333/app-java-0.0.1-SNAPSHOT/  
  
What do we see [now](https://app.datadoghq.com/apm/traces)?  
  
2) Single-step instrumentation - reapply the non-admission controller application  
  
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
