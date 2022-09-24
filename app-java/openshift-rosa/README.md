ROSA Documentation
--

A: Datadog Agent Installation and Configuration  

1) Configure values file located
[here](https://gist.github.com/jgibbons-cp/edc33a0e96c8f2f2ef393eef201edea2).  

- Change:  
  - ```clustername: openshift``` to ```clustername: <clustername>```  
  - Add your apiKey and appKey from the ACCESS menu
[here](https://app.datadoghq.com/organization-settings/users).  Rather than
add them in the values file you can add them as secrets as documented
[here](https://github.com/DataDog/helm-charts/blob/main/charts/datadog/values.yaml#L29-L49).  
  - Uncomment ```#useHostNetwork: true```  

2) Add and update the Datadog repo:  

   ```
   helm repo add datadog https://helm.datadoghq.com
   helm repo update
   ```  

3) Create a datadog project to install the agents:  

   ```
   oc new-project datadog --display-name 'datadog'
   ```  

4) In the Datadog project apply with
```
helm install <release> -f values.yaml datadog/datadog
```

4) View the deployed pods:  

```
oc get pods
```  
and you will see something like this:  

NAME                                              READY   STATUS    RESTARTS   AGE  
dd-agent-datadog-5zxzn                            5/5     Running   0          72m  
dd-agent-datadog-cluster-agent-5f8cf4756f-nl269   1/1     Running   0          72m  
dd-agent-datadog-ggjfn                            5/5     Running   0          71m  
dd-agent-datadog-k66fd                            5/5     Running   0          70m  
dd-agent-datadog-wrdsd                            5/5     Running   0          70m  
dd-agent-datadog-x4md5                            5/5     Running   0          69m  

5) NOTE: This should not be required as the values file applies it via the
agents: podSecurity: Apply the custom Datadog scc for all features documented
[here](https://docs.datadoghq.com/integrations/openshift/?tab=daemonset#custom-datadog-scc-for-all-features)
 by saving the [scc](https://github.com/DataDog/datadog-agent/blob/main/Dockerfiles/manifests/openshift/scc.yaml)
 to a file and applying it:  

   ```
   oc create -f <file.yaml>
   ```  

6) NOTE: The Kubernetes controller manager, manager, and API server checks as
well as the coredns check will be run as cluster checks.  You can verify this
in the cluster agent status Cluster Checks Dispatching section:  

```
oc exec -it <cluster-agent-name> -- agent status
```  

```Cluster Checks Dispatching  
==========================  
  Status: Leader, serving requests  
  Active agents: 5  
  Check Configurations: 4  
    - Dispatched: 4  
    - Unassigned: 0  
```  

7) Each check will be an endpoint check dispatched to one agent which you can see
in a status of the agent:  

```
oc exec -it <agent-name> -- agent status  
```  

which will look like this:  

```  
kube_apiserver_metrics (3.2.0)  
------------------------------  
  Instance ID: kube_apiserver_metrics:5f8d4418e8110cca [OK]  
  Configuration Source: file:/etc/datadog-agent/conf.d/kube_apiserver_metrics.yaml  
  Total Runs: 312  
  Metric Samples: Last Run: 12,363, Total: 5,470,371  
  Events: Last Run: 0, Total: 0  
  Service Checks: Last Run: 1, Total: 312  
  Average Execution Time : 1.729s  
  Last Execution Date : 2022-09-24 19:46:18 UTC (1664048778000)  
  Last Successful Execution Date : 2022-09-24 19:46:18 UTC (1664048778000)  
  ```  

B: OpenShift Metrics

openshift.* metrics come from the Kubernetes API Server as documented
[here](https://docs.datadoghq.com/integrations/openshift/?tab=daemonset#overview).
To see them, quotas must be enabled and used.  Cluster Resource Quotas are
documented [here](https://docs.openshift.com/container-platform/4.6/applications/quotas/quotas-setting-across-multiple-projects.html). An example for a project named app-java can be see here:  

```
oc create clusterresourcequota app-java     --project-label-selector=kubernetes.io/metadata.name=app-java --hard=pods=10 --hard=secrets=20
```

which creates the quota.  The quota can be viewed like such:  

```  
$ oc describe AppliedClusterResourceQuota  
Name:		app-java  
Created:	About an hour ago  
Labels:		<none>  
Annotations:	<none>  
Namespace Selector: ["app-java"]  
Label Selector: kubernetes.io/metadata.name=app-java  
AnnotationSelector: map[]  
Resource	Used	Hard  
--------	----	----  
pods		1	10  
secrets		7	20  
```  

and now we can see openshift.* metrics in datadog
[here](https://app.datadoghq.com/metric/summary?filter=openshift).  

C: Tracing a Java App on ROSA

Basic app that has a servlet front-end and talks to MySQL.  This deploys
on ROSA and incudes Datadog RUM, APM and application security.  

NOTE: mysql is going into a crashloopbackoff based on the securityContext
required in ROSA.  I have not had time to fix it and may or may not based on
whether I need to.  That being said, the app traces showing 500s.  

a: Manifests

1) app-java.yaml - manifest to deploy app and a service to hit the app via a
LoadBalancer  

2) mysql_ja.yaml - n/a based on note above

b: Deploy  

1) Create secret for RUM replacing the values with your keys from your
[RUM project](https://app.datadoghq.com/rum/list?from_ts=1663967470366&to_ts=1664053870366&live=true)  

 ```
 oc create secret generic dd-rum-tokens --from-literal CLIENT_TOKEN=TOKEN --from-literal APPLICATION_ID=APPID  
 ```  

3) Deploy app ```oc create -f app-java.yaml```

2) Deploy MySQL: n/a  

3) Lock down the load  balancer rules to accept traffic from your IP

Hit it at ```http://LoadBalancer:8080/app-java-0.0.1-SNAPSHOT/```
and look at [traces](https://app.datadoghq.com/apm/traces?query=env%3Alab&cols=core_service%2Ccore_resource_name%2Clog_duration%2Clog_http.method%2Clog_http.status_code&historicalData=false&messageDisplay=inline&sort=desc&start=1664053077903&end=1664053977903&paused=false).    
