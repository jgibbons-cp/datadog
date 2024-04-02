Install the Datadog Agent with the Daemonset
--

At times you may find that for various reasons teams are not able to use helm to 
install the agent and need to use the daemonset.  Installing the native daemonset is complicated 
and error prone.  
  
This can be done easily using helm to create a single manifest that can be applied with ```kubectl```.  
  
The process is described [here](https://medium.com/@jenksgibbons/simplifying-complex-k8s-objects-without-helm-with-helm-76843d105b38).   
  
Steps:  
  
- Get a values file to configure the agent.  
  ```
  wget https://raw.githubusercontent.com/jgibbons-cp/datadog/main/kubernetes/aks_with_windows/values.yaml  
  ```  
- Configure the agent using the values file  
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
- Set the clustername tag  
  ```  
  clusterName: <tag>  
  ```  
- Create the manifests  
  ```
  helm template datadog-agent -f values.yaml datadog/datadog --namespace datadog > agent.yaml  
  ```  
- Install the ds
  ```
  kubectl create -f agent.yaml
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
  kubectl delete -f agent.yaml  
  ```  
- No pods  
  ```  
  kubectl get pods  
  ```  
- Switch back to default namespace and delete datadog ns
  ```  
  kubectl config set-context --current --namespace=default && kubectl delete ns datadog
  ```  
