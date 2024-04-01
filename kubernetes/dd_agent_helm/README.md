Install the Datadog Agent with Helm
--

0. Create a directory and go into it
1. ```kubectl get pods```  
   If this does not return anything set your KUBECONFIG to your config.  
   ```export KUBECONFIG=/path/to/config```  
2. ```helm```  
   If this returns that it is not installed install it  
   ```brew install helm```  
   If you don't have brew, install it then install helm with it.  
3. Let's install this in another namespace. Create it and switch to it.
   ```  
   kubectl create ns datadog && kubectl config set-context --current --namespace=datadog
   ```  
4. Get a Linux values file  
   ```  
   wget https://raw.githubusercontent.com/jgibbons-cp/datadog/main/kubernetes/aks_with_windows/values.yaml
   ```  
5. Add and update our repo  
   ```  
   helm repo add datadog https://helm.datadoghq.com  
   helm repo update  
   ```  
6. Install it  
   ```
   helm install dd-agent -f values.yaml datadog/datadog -n datadog
   ```
7. To watch the pods while the are deploying  
   ```  
   watch kubectl get pods  
   ```  
8. All the pods will go into an error state, why and how can we tell?
9. 
10. Create a secret  
    ```
    # scaling based on metrics requires app key
    kubectl create secret generic datadog-agent --from-literal api-key=<key> --from-literal app-key=<key> -n datadog
    ```  
11. Take out features that won't work on Mac and/or Windows  
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
12. Update the agent  
    ```  
    helm upgrade dd-agent -f values.yaml datadog/datadog  
    ```  
13. Watch redeploy  
    ```  
    watch kubectl get pods  
    ```  
14. Check status of agents  
    ```  
    kubectl exec -it $(kubectl get pods -o custom-columns="POD NAME":.metadata.name --no-headers | grep -v cluster | sed -n 1p) -- agent status  
  
    kubectl exec -it $(kubectl get pods -o custom-columns="POD NAME":.metadata.name --no-headers | grep cluster | sed -n 1p) -- agent status  
    ```  
15. Do you see any issues in either agent status?  If not, go to the [container orchestrator](https://app.datadoghq.com/orchestration/overview/pod).  Do you see any pods etcetera?  Why not?  
  
16. What got installed  
    ```  
    kubectl get all  
    kubectl get secrets  
    kubectl get sa  
    kubectl get role  
    kubectl get rolebinding  
    kubectl get clusterrole | grep datadog  
    kubectl get clusterrolebinding | grep datadog  
    ```  
16. Uninstall agent  
    ```  
    helm uninstall dd-agent  
    ```  
17. No pods  
    ```  
    kubectl get pods  
    ```  
18. Switch back to default namespace and delete datadog ns
    ```  
    kubectl config set-context --current --namespace=default && kubectl delete ns datadog
    ```  
