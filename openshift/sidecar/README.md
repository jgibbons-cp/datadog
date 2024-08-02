Create an OpenShift Pod with the Datadog Agent as a Sidecar
--

The recommended way to monitor Kubernetes nodes and pods is using a DaemonSet. In this manner each node where an agent is installed counts as a host. There may be additional charges if the allowable number of containers per host is reached. There are certain situations where you may want a sidecar for the Datadog agent.  When configured in this manner, when the DaemonSet is recommended for the cluster type, each pod counts as a host.  
  
To create an application pod with a Datadog agent sidecar:  
  
* Install the datadog helm chart  
  
  ```  
  helm repo add datadog https://helm.datadoghq.com  
  ```  
  
* Update the chart in case you already have it  
  
  ```  
  helm repo update  
  ```  

* Create an environment variable for the namespace/OpenShift project  
  
  ```  
  export NAMESPACE=<namespace>  
  ```  

* Use ```helm template``` to create the base DaemonSet  
  ```  
  helm template datadog-agent -f openshift_helm_values.yaml datadog/datadog --namespace $NAMESPACE > openshift_agent_ds.yaml  
  ```  

* Create a new project in OpenShift  
  ```  
  oc new-project $NAMESPACE  
  ``` 

* Get your API and APP keys. Datadog keys are located at 1: [API keys](https://app.datadoghq.com/organization-settings/api-keys) and 2: [APP keys](https://app.datadoghq.com/organization-settings/application-keys)  
  
* Create a secret for the keys  

```  
oc create secret generic datadog-secret --from-literal api-key=<API_KEY> --from-literal app-key=<APP_KEY>  
```  

* Copy the DaemonSet manifest to <file_name>.yaml to create an application pod with a Datadog agent sidecar  
  
* Change ```metadata.name```  
  
* Search for ```kind: DaemonSet``` and change to ```kind: Deployment```  
  
* Add in your application container(s) into spec.template.spec.containers[0-n]  
  
* Apply the manifest  
  
  ```  
  oc apply -f <file>processes
  ```  
  
This will monitor the containers in the POD.  You will not see the cluster or the pods in the live Kubernetes [view](https://app.datadoghq.com/orchestration/explorer/pod?explorer-na-groups=false&panel_tab=logs) since we are not monitoring pods with the node agents, but will see the [containers](https://app.datadoghq.com/containers?selectedTopGraph=timeseries).  
  
Follow the process for any project where you would like to run one of these pods and/or to create new pods with a Datadog agent sidecar.  
