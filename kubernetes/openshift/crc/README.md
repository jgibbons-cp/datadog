CRC and Datadog
--

[CRC](https://crc.dev/docs/introducing/) "brings a minimal OpenShift Container Platform 4 cluster to your local computer. This runtime provides minimal environments for development and testing purposes."  

- Installing Datadog's operator on CRC - why? Commercial OpenShift environments are difficult to bring up (e.g cloud infrastructure limits, personal account using Brex as they are large expensive clusters).  This provides a viable, affordable environment for learning to prepare for working with OpenShift customers.  

1) [Install CRC](https://crc.dev/crc/getting_started/getting_started/installing/)  
  
2) Set the disk size to avoid issues - ```crc config set disk-size 62``` - as an example of what I used.  
  
3) Start the instance - ```crc start```  When the `start` completes you will see:  
    
```  
Started the OpenShift cluster.  
  
The server is accessible via web console at:  
  https://console-openshift-console.apps-crc.testing  
  
Log in as administrator:  
  Username: kubeadmin  
  Password: RxxxxxxxrP  
  
Log in as user:  
  Username: developer  
  Password: developer  
  
Use the 'oc' command line interface:  
  $ eval $(crc oc-env)  
  $ oc login -u developer https://api.crc.testing:6443  
```  
  
NOTE: if you ever need to get credentials enter ```crc console --credentials```  
  
4) Setup OpenShift's CLI client, their version of ```kubectl```, with ```eval $(crc oc-env)```  
  
5) Login to use ```oc```.  This is different from just setting ```KUBECONFIG``` or moving the config to ~/.kube  Login and you can the use the CLI.  
  
6) Navigate to [OperatorHub](https://console-openshift-console.apps-crc.testing/operatorhub/all-namespaces?keyword=datadog). Install the [community operator](https://console-openshift-console.apps-crc.testing/operatorhub/all-namespaces?keyword=datadog&details-item=datadog-operator-community-operators-openshift-marketplace&channel=stable&version=1.12.1).  
  
7) UI - the Datadog operator used to not be available in the CRC UI by default.  It appears to be in by default now, however if it is not there apply the following:  
  
```  
apiVersion: operators.coreos.com/v1alpha1  
kind: Subscription  
metadata:  
  name: datadog-subscription  
  namespace: openshift-operators  
spec:  
  channel: stable  
  name: datadog-operator  
  source: community-operators  
  sourceNamespace: openshift-marketplace  
```  
  
7) Take a look at the running ```operator```:  
  
```  
$ oc get po -n openshift-operators  
NAME                                        READY   STATUS    RESTARTS   AGE  
datadog-operator-manager-7c7cb97985-ddnk9   1/1     Running   0          101m  
```  

8) The operator will be bundled with the SCC.  
  
9) Let's install the agent.  Navigate to [Installed Operators](https://console-openshift-console.apps-crc.testing/k8s/all-namespaces/operators.coreos.com~v1alpha1~ClusterServiceVersion)  
  
10) Click on the [Create Instance](https://console-openshift-console.apps-crc.testing/k8s/ns/openshift-operators/clusterserviceversions/datadog-operator.v1.12.1/datadoghq.com~v2alpha1~DatadogAgent/~new) in the ```Datadog Agent``` tile  
  
11) Click on YAML view.  This will provide a basic agent CRD manifest.  Configuration documentation is [here](https://github.com/DataDog/datadog-operator/blob/main/docs/configuration.v2alpha1.md).  
  
Change the template before we apply:  
  
```  
# change  
     apiKey: <DATADOG_API_KEY>  
      appKey: <DATADOG_APP_KEY>  
  
# to  
   credentials:  
      apiSecret:  
        secretName: datadog-agent  
        keyName: api-key  
      appSecret:  
        secretName: datadog-agent  
        keyName: app-key  
  
# remove  
   clusterAgentToken: <DATADOG_CLUSTER_AGENT_TOKEN>  

# set the clustername  
   clusterName: <CLUSTER_NAME>
```  
  
12) Create a secret in the ```openshift-operators``` namespace.  
  
```  
oc create secret generic datadog-agent --from-literal api-key=<API_KEY> --from-literal app-key=<APP_KEY> -n openshift-operators  
```  
  
13) Click ```Create``` in the UI to deploy.  
  
14) Wait for the agent to deploy.  
  
```  
Every 2.0s: kubectl get pod -n openshift-operators                     Thu Mar  6 17:28:01 2025  

NAME                                                         READY   STATUS    RESTARTS   AGE  
datadog-operator-manager-7c7cb97985-ddnk9                    1/1     Running   0          4h51m  
datadogagent-sample-agent-rcxnj                              2/2     Running   0          5m16s  
datadogagent-sample-cluster-agent-7485cb9d5c-69879           1/1     Running   0          5m16s  
datadogagent-sample-cluster-agent-7485cb9d5c-zpn74           1/1     Running   0          5m16s  
datadogagent-sample-cluster-checks-runner-65d487b9db-2xkqm   1/1     Running   0          5m15s  
datadogagent-sample-cluster-checks-runner-65d487b9db-9mkj5   1/1     Running   0          5m15s  
```  
  