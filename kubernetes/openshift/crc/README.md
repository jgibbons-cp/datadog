CRC and Datadog
--

[CRC](https://crc.dev/docs/introducing/) "brings a minimal OpenShift Container Platform 4 cluster to your local computer. This runtime provides minimal environments for development and testing purposes."  

- Installing Datadog's operator on CRC - why? Commercial OpenShift environments are difficult to bring up (e.g cloud infrastructure limits, personal account, enxpensing outside of Expensify as they are large expensive clusters).  This provides a viable, affordable environment for learning to prepare for working with OpenShift customers.  

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
  
4) Setup OpenShift's CLI client, their version of ```kubectl```, with ```eval $(crc oc-env)```  
  
5) Login to use ```oc```.  This is different from just setting ```KUBECONFIG``` or moving the config to ~/.kube  Login and you can the use the CLI.  
  
6) We will install in the project ```openshift-operators```  To use this we need to be logged in as ```kubeadmin```  Once logged in switch to the project with ```oc project openshift-operators```  
  
7) When installing with a cloud/commercial offering the operator will be bundled with the scc creation.  In crc you need to create it.  
  
- [SCC](https://docs.openshift.com/container-platform/4.13/authentication/managing-security-context-constraints.html#:~:text=In%20OpenShift%20Container%20Platform%2C%20you,some%20Operators%20or%20other%20components.) - In OpenShift Container Platform, you can use security context constraints (SCCs) to control permissions for the pods in your cluster.  
  
Default SCCs are created during installation and when you install some Operators or other components. As a cluster administrator, you can also create your own SCCs by using the OpenShift CLI (oc).  
  
```
wget https://raw.githubusercontent.com/DataDog/datadog-agent/main/Dockerfiles/manifests/openshift/scc.yaml && sed -i.bak 's/default:datadog-agent/openshift-operators:datadog-agent-scc/g' scc.yaml && oc apply -f scc.yaml
```  
  
8) Install the operator  
  
```  
helm repo add datadog https://helm.datadoghq.com &&  
helm repo update &&  
helm install dd-operator datadog/datadog-operator  
```  
  
9) Create a secret for your agent - ```oc create secret generic datadog-secret --from-literal api-key=<API_KEY> --from-literal app-key=<APP_KEY>```  
  
10) Install the agent using the manifest from [here](https://github.com/DataDog/datadog-operator/blob/main/docs/install-openshift.md#deploy-the-datadog-agent-with-the-operator) using ```oc apply -f <DD_OPERATOR_AGENT_YAML>  The service account will be created from this.

UI
--

The Datadog operator is not available in the CRC UI by default.  To add apply the following:  
  
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

