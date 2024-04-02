Install the Datadog Agent with the Operator
--
  
The agent can also be installed using the Datadog [operator](https://docs.datadoghq.com/getting_started/containers/datadog_operator/).  To 
do so:  
  
- Install the Datadog operator  
  ```
  helm install dd-operator datadog/datadog-operator
  ```  
- Get a manifest with logs, APM, process, and metrics collection enabled.  
  ```
  wget https://raw.githubusercontent.com/DataDog/datadog-operator/main/examples/datadogagent/v2alpha1/datadog-agent-all.yaml
  ```  
- Replace:  
  ```  
  global:  
    credentials:  
      apiKey: <DATADOG_API_KEY>  
      appKey: <DATADOG_APP_KEY>  
  ```  
with  
  ```  
  global:  
    clusterName: <cluster_name_tag>  
    credentials:  
      apiSecret:  
        secretName: datadog-agent  
        keyName: api-key  
      appSecret:  
        secretName: datadog-agent  
        keyName: app-key  
  ```  
- Unless you are using a cluster other than minikube or kind change the following to false
  ```
  ebpfCheck
  cspm
  cws
  npm
  usm
  ```
- Unless you are using a cluster other than minikube or kind add in the global section  
  ```
  global:  
    kubelet:  
      tlsVerify: false  
  ```
- Apply the manifest  
  ```
  kubectl apply -f /path/to/datadog-agent-all.yaml
  ```  
- Watch the startup of the agents  
  ```  
  watch kubectl get pods  
  ```  
- Check status of agents  
  ```  
  kubectl exec -it $(kubectl get pods -o custom-columns="POD NAME":.metadata.name --no-headers | grep -v cluster | sed -n 1p) -- agent status  
  
  kubectl exec -it $(kubectl get pods -o custom-columns="POD NAME":.metadata.name --no-headers | grep cluster | sed -n 1p) -- agent status  
  ```  
- What got installed  
    ```  
    kubectl get all  
    kubectl get secrets  
    kubectl get sa  
    kubectl get role  
    kubectl get rolebinding  
    kubectl get clusterrole | grep datadog  
    kubectl get clusterrolebinding | grep datadog  
    ```  
- Uninstall agent  
    ```  
    kubectl delete -f /path/to/datadog-agent-all.yaml  
    ```  
- No pods  
    ```  
    kubectl get pods  
    ```  
