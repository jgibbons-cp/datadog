Install the Datadog Agent with the Operator
--
  
The agent can be installed using the Datadog [operator](https://docs.datadoghq.com/getting_started/containers/datadog_operator/).  To 
do so:  
  
- Install the Datadog operator  
  ```
  helm install dd-operator datadog/datadog-operator
  ```  
- Pull a sample manifest with logs, APM, live processes, and metrics enabled.  You can further configure it using the documentation 
[here](https://github.com/DataDog/datadog-operator/blob/main/docs/configuration.v2alpha1.md#manifest-templates).  
  
```  
wget https://raw.githubusercontent.com/DataDog/datadog-operator/main/examples/datadogagent/datadog-agent-all.yaml  
```  
  
Configure the manifest to use a secret for your application and API key.  

Replace  
  
  ```    
    clusterName: my-example-cluster  
    credentials:  
      apiKey: <DATADOG_API_KEY>  
      appKey: <DATADOG_APP_KEY>    
  ```  
    
  with (watch your indentation especially if you use the click copy on the far right)   
    
  ```  
    clusterName: <cluster_name_tag>  
    credentials:  
      apiSecret:  
        secretName: datadog-agent  
        keyName: api-key  
      appSecret:  
        secretName: datadog-agent  
        keyName: app-key  
  ```  
    
Change <cluster_name_tag> to whatever you want your tag to be.  
  
- If you are using minikube or kind change the following to false (why?)
  ```
  ebpfCheck
  cspm
  cws
  npm
  usm
  ```
- If are using minikube, kind, AKS or kubeadm add in the global section  
  ```  
    kubelet:  
        tlsVerify: false  
  ```  
- Add and override section to the spec at the bottom
  ```
  override:
    nodeAgent:
      env:
        - name: DD_HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName  
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

- Why do you see a status of CreateContainerConfigError? How do we investigate? How do we fix? When we do fix what happens/why?  
  
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
- Uninstall the operator  
  ```
  helm uninstall dd-operator  
  ```
- Get pods  
  ```
  kubectl get po  
  ```
