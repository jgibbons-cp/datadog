Run an ASPNet48 MVC Windows Server Core LTSC 2019 App and Trace with Datadog
--

For a multi OS cluster and Datadog agent
setup see
[here](https://github.com/jgibbons-cp/datadog/tree/main/kubernetes/aks_with_windows)
NOTE: for hostPort to work the CNI must support it.  The CNI on AKS and GKE
supports hostPort.  If hostPort is not supported, on Kubernetes >= 1.22, the
agent Service can route traffic to the agent pod on the same node with
```  
internalTrafficPolicy: Local  
```  
.  

To build the container we will use here see
[here](https://github.com/jgibbons-cp/datadog/tree/main/docker/aspnet48_mvc_app)  

Deploy and trace on K8
--

1) Deploy the pod  

NOTE: I have been unable to get container and K8 tags in my traces on AKS.  I have
worked around this using something like this in the application manifest:  

```  
- name: POD_NAME  
  valueFrom:  
    fieldRef:  
      fieldPath: metadata.name  
- name: DD_TAGS  
  value: pod_name:$(POD_NAME)  
```  

```
kubectl create -f asp_dotnet_sample.yaml  
```

and you should see the pod running  

```
kubectl get po | grep sample
sample-7d7f4bf7db-lrnxj                           1/1     Running   0          66s
```  

2) Expose the application via a load balancer  (assuming EKS but expose how you
   need to)

```
kubectl expose deploy sample --port 80 --target-port 80 --type LoadBalancer  
```  

and add security group rules to allow traffic if needed  

3) Hit the application  

```
http://<load_balancerFQDN>
```  

4) Go looks at traces [here](https://app.datadoghq.com/apm/traces)  

Have fun...  
