Install Datadog Agent with APM on OpenShift
--

This includes a values file to install the Datadog agent and cluster agent with
helm on OpenShift.

This is based on the
[OpenShift documentation](https://docs.datadoghq.com/integrations/openshift/?tab=helm)
and the [K8 documentation](https://docs.datadoghq.com/agent/kubernetes/?tab=helm)  

I used the following scc configuration, however review the documentation to see
if your setup requires more:  

```
agents:
...
  podSecurity:
    securityContextConstraints:
      create: true
...
```

NOTE: I am using ```kubectl``` rather than ```oc``` however the instructions will
be the same with ```oc``` as far as I understand.    

The values file uses a secret rather than
[API/APP](https://app.datadoghq.com/organization-settings/users) keys from the
helm install line so:  

1) kubectl create secret generic datadog-agent --from-literal api-key=KEY --from-literal app-key=KEY  
2) Has [APM - Application Performance Monitoring](https://docs.datadoghq.com/tracing/)
turned on  
2) tlsVerify: false - if you get an error on the kubelet check when running  
3) clusterName: CLUSTERNAME  - add your clustername to the config

Logs and statsd can be turned on via the values file.  

Once running you can check the agent status for the agent and cluster agent with:  

```kubectl exec -it PODNAME -- agent status```  
