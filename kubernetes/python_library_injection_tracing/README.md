Python Tracing - Datadog Library Injection
--

This will show a simple example of tracing a python [application](https://github.com/docker/awesome-compose/tree/master/flask) 
in Kubernetes using Datadog's Library Injection.  
  
1) Install the [Operator](https://docs.datadoghq.com/getting_started/containers/datadog_operator/)
using the provided datadog-agent.yaml  
    
From the documentation:  
  
```  
# add the repo  
helm repo add datadog https://helm.datadoghq.com  
  
# install the operator  
helm install dd-operator datadog/datadog-operator  
  
# create secret for agent(s)  
kubectl create secret generic datadog-agent --from-literal api-key=<API_KEY> --from-literal app-key=<APP_KEY>  
  
# Apply the [configuration](https://github.com/DataDog/datadog-operator/blob/main/docs/configuration.v2alpha1.md) 
# for the agents, this config has the agent, trace and process containers  
kubectl apply -f /<path>/datadog-agent.yaml  
  
# Look at what is running  
$ kubectl get pods -n default  
NAME                                            READY   STATUS    RESTARTS   AGE  
datadog-agent-d25z9                             3/3     Running   0          3m45s  
datadog-cluster-agent-7f679d78d4-zdgfr          1/1     Running   0          4m30s  
dd-operator-datadog-operator-5f49c8c597-vzfg8   1/1     Running   0          6m44s  
```  
  
2) Run the non-instrumented application (optional, but you get the point)  
  
```  
# deploy  
kubectl apply -f py_no_injection.yaml  
  
# setup access to hit localhost:33333  
kubectl port-forward deployment.apps/py-test-no-tracer 33333:8000  
```  
  
In a browser hit ```http://localhost:33333``` and when done kill the ```port-forward``` command.  
  
Delete the non-instrumented deployment - ```kubectl delete -f py_no_injection.yaml```  
  
3) Go look at [traces](https://app.datadoghq.com/apm/traces) -> no instrumentation -> no traces  
  
4) [Instrument](https://docs.datadoghq.com/tracing/trace_collection/library_injection_local/?tab=kubernetes) 
the application by adding some labels and an annotation.  
  
You can see the differences here:  
  
![alt text](https://github.com/jgibbons-cp/datadog/blob/main/kubernetes/python_library_injection_tracing/instrumentation_changes.png?raw=true)  
  
5) Either instrument the non-istrumented or use the instrumented and deploy.  
  
```  
# instrumented  
kubectl apply -f py_auto_injection.yaml  
  
# see the init container doing the library injection  
kubectl get po | grep py-test-tracer  
py-test-tracer-7b59bb747c-57dx6                 0/1     Init:0/1   0          5s  
  
kubectl get po | grep py-test-tracer  
py-test-tracer-7b59bb747c-57dx6                 1/1     Running   0          83s  
  
# setup access to hit localhost:33333  
kubectl port-forward deployment.apps/py-test-tracer 33333:8000  
```  
  
The init container can also be seen in the live pods [view](https://app.datadoghq.com/orchestration/overview/pod):  
  
![alt text](https://github.com/jgibbons-cp/datadog/blob/main/kubernetes/python_library_injection_tracing/live_containers_view.png?raw=true)  


In a browser hit ```http://localhost:33333``` a few times to get some requests and when done kill the ```port-foward``` command.  
    
6) Look at [traces](https://app.datadoghq.com/apm/traces)  
  
![alt text](https://github.com/jgibbons-cp/datadog/blob/main/kubernetes/python_library_injection_tracing/trace.png?raw=true)  
  
Delete the instrumented deployment - ```kubectl delete -f py_auto_injection.yaml```  
  
Have fun.  


