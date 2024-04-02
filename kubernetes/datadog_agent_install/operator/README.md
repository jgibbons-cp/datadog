Install the Datadog Agent with the Operator
--
  
The agent can also be installed using the Datadog [operator](https://docs.datadoghq.com/getting_started/containers/datadog_operator/).  To 
do so:  
  
- Install the Datadog operator  
  ```helm install dd-operator datadog/datadog-operator```  
- Get a manifest with logs, APM, process, and metrics collection enabled.  
  ```wget https://raw.githubusercontent.com/DataDog/datadog-operator/main/examples/datadogagent/v2alpha1/datadog-agent-all.yaml```  
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
- Apply the manifest  
  ```kubectl apply -f /path/to/datadog-agent-all.yaml```  
- Watch the startup of the agents  
    ```  
    watch kubectl get pods  
    ```  
- Check status of agents  
    ```  
    kubectl exec -it $(kubectl get pods -o custom-columns="POD NAME":.metadata.name --no-headers | grep -v cluster | sed -n 1p) -- agent status  
  
    kubectl exec -it $(kubectl get pods -o custom-columns="POD NAME":.metadata.name --no-headers | grep cluster | sed -n 1p) -- agent status  
    ```  
- Do you see any issues in either agent status?  If not, go to the [container orchestrator](https://app.datadoghq.com/orchestration/overview/pod).  Do you see any pods etcetera?  Why not?  
  
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
- Switch back to default namespace and delete datadog ns
    ```  
    kubectl config set-context --current --namespace=default && kubectl delete ns datadog
    ```  
