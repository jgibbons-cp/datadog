Install the Datadog Agent with Helm
--

- Get a Linux values file  
   ```  
   wget https://raw.githubusercontent.com/jgibbons-cp/datadog/main/kubernetes/aks_with_windows/values.yaml
   ```  
- Install the agent  
   ```
   helm install dd-agent -f values.yaml datadog/datadog -n datadog
   ```
- To watch the pods while the are deploying  
   ```  
   watch kubectl get pods  
   ```  
- All the pods will go into an error state, why and how can we tell?
- Take out features that won't work on Mac and/or Windows  
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
- Update the agent  
    ```  
    helm upgrade dd-agent -f values.yaml datadog/datadog  
    ```  
- Watch redeploy  
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
    helm uninstall dd-agent  
    ```  
- No pods  
    ```  
    kubectl get pods  
    ```  
- Switch back to default namespace and delete datadog ns
    ```  
    kubectl config set-context --current --namespace=default && kubectl delete ns datadog
    ```  
