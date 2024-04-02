Install the Datadog Agent with Helm
--
- Do the common items at the root of this repo.  
- Get a values file to configure the agent  or use the one you used for the ds install. 
   ```  
   wget https://raw.githubusercontent.com/jgibbons-cp/datadog/main/kubernetes/aks_with_windows/values.yaml
   ```  
- Take out features that won't work on Mac and/or Windows or use the values file you did with the ds.  
    ```
    networkMonitoring:
    # datadog.networkMonitoring.enabled -- Enable network performance monitoring
      enabled: false

    # Enable security agent and provide custom configs
    securityAgent:
      compliance:
        # datadog.securityAgent.compliance.enabled -- Set to true to enable Cloud Security Posture Management (CSPM)
        enabled: false

        runtime:
        # datadog.securityAgent.runtime.enabled -- Set to true to enable Cloud Workload Security (CWS)
        enabled: false

        # datadog.securityAgent.runtime.fimEnabled -- Set to true to enable Cloud Workload Security (CWS) File Integrity Monitoring
        fimEnabled: false

        network:
            # datadog.securityAgent.runtime.network.enabled -- Set to true to enable the collection of CWS network events
            enabled: false
    ```  
- Set the clustername tag if the values file is new  
  ```  
  clusterName: <tag>  
  ```  
- Install the agent  
   ```
   helm install dd-agent -f values.yaml datadog/datadog
   ```
- Watch the pods while they are deploying  
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
    helm uninstall dd-agent  
    ```  
- No pods  
    ```  
    kubectl get pods  
    ```  
