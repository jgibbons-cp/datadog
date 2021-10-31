Run an ASPNet48 MVC Windows Server Core LTSC 2019 App and Trace with Datadog
--

For a multi OS cluster and Datadog agent
setup see
[here](https://github.com/jgibbons-cp/datadog/tree/main/kubernetes/eks_with_windows)  

To build the container we will use here see
[here](https://github.com/jgibbons-cp/datadog/tree/main/docker/aspnet48_mvc_app)  

Deploy and trace on K8
--

1) Deploy the pod  

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

4) Connect the trace agent to the Datadog agent with a service on the agent
after getting pod for Datadog Windows agent pod with (with sample pod name):  

```
$ kubectl get po | grep win
dd-agent-win-datadog-v9rtc                        3/3     Running   0          25h
```   

```
kubectl expose pod dd-agent-win-datadog-v9rtc --name dd-agent --port 8126
--target-port 8126 --selector="app=dd-agent-win-datadog"  
```  

NOTE: this seems odd to me, but it works across restarts of the Datadog agent.
It is a ds not a deploy so I exposed the pod with a selector.  I would expect it
to break when the agent is redeployed but it does not.  I think it is the selector
but need to look at it.  

5) Go looks at traces [here](https://app.datadoghq.com/apm/traces)  

Have fun...  
