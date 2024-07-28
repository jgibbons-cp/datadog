Install the Datadog Agent with the Operator
--

Items common to all installation methods:  
  
Get a cluster  
  
```  
wget https://raw.githubusercontent.com/jgibbons-cp/datadog/main/kubernetes/lab/cluster/setup.sh  
sh setup.sh  
```  
  
```
kubectl get pods  
```  
  
If this does not return anything set your KUBECONFIG to your config.  
  
```
export KUBECONFIG=/path/to/config  
```  
  
```  
helm  
```  
  
If this returns that it is not installed install it  
  
```
brew install helm  
```  
  
If you don't have brew, install it then install helm with it.  

- Add and update the Datadog repo  
  
```  
helm repo add datadog https://helm.datadoghq.com  
helm repo update  
```  
  
- What are [namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)?  Why would we want to install in a particular namespace other than ```default```?  Let's install this in another namespace. Create it and switch to it.  
  
```  
kubectl create ns datadog && kubectl config set-context --current --namespace=datadog
```  
  
- Create a secret.  How would this command be different if we had not switched context?  
  
```
kubectl create secret generic datadog-secret --from-literal api-key=<key> --from-literal app-key=<key>  
```  
  
The agent can be installed using the Datadog [operator](https://docs.datadoghq.com/getting_started/containers/datadog_operator/).  To 
do so:  
  
- Install the Datadog operator  
  
  ```
  helm install dd-operator datadog/datadog-operator
  ```  
  
What is running?  
  
```  
kubectl get po  
kubectl describe po <operator_pod_name>  
```  
  
What can we see in the describe?  
  
- Pull a sample manifest with logs, APM, live processes, and metrics enabled.  You can further configure it using the documentation 
[here](https://github.com/DataDog/datadog-operator/blob/main/docs/configuration.v2alpha1.md#manifest-templates).  
  
```  
wget https://raw.githubusercontent.com/DataDog/datadog-operator/main/examples/datadogagent/datadog-agent-all.yaml  
# or curl -O <URL>  
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
  
In the logs section, below:  
  
```  
    logCollection:  
      enabled: true  
```  
  
add  
  
```  
      containerCollectAll: true  
```  
  
- If you are using minikube or kind change the following to false (why?)
  ```
  ebpfCheck
  cspm
  cws
  npm
  usm
  ```
- If are using minikube, kind, AKS or kubeadm add in the global section (why?)  
  ```  
      kubelet:  
          tlsVerify: false  
  ```  
- Add and override section to the spec at the bottom (why?)
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
  kubectl apply -f datadog-agent-all.yaml
  ```  
- Watch the startup of the agents  
  ```  
  watch kubectl get pods  
  ```  

- Why do you see a status of CreateContainerConfigError? How do we investigate? How do we fix? When we do fix what happens/why?  
  
- That is fixed when you look at the pods do you see anything odd?  
  
  ```  
  k get nodes  
  k describe nodes | grep -i taint
  ```  
    
  What is a [taint](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)? 
  Why is it there? How do we deploy to that node if we want to do so?  

  Let's add a toleration to the ```spec.override.nodeAgent``` section.  How do you walk the YAML?  
     
  ```  
        tolerations:
          - key: envnode kubernetes.io/hostname
            operator: Equal
            value: minikube
            effect: NoSchedule  
  ```  
  
Apply the manifest  
  
```  
k apply -f datadog-agent-all.yaml  
```  
  
- How many agents now?  
  
  ```  
  kubectl get po | grep datadog-agent | wc -l  
  ```  

- Check status of agents  
  ```  
  kubectl exec -it $(kubectl get pods -o custom-columns="POD NAME":.metadata.name --no-headers | grep -v cluster | sed -n 1p) -- agent status  
  
  kubectl exec -it $(kubectl get pods -o custom-columns="POD NAME":.metadata.name --no-headers | grep cluster | sed -n 1p) -- agent status  
  ```  

- In the running pods, what got installed?  
  
  ```  
  $ kubectl describe po | grep "Started container"  
  Normal  Started    3m26s  kubelet            Started container init-volume  
  Normal  Started    3m26s  kubelet            Started container init-config  
  Normal  Started    3m25s  kubelet            Started container seccomp-setup  
  Normal  Started    3m24s  kubelet            Started container agent  
  Normal  Started    3m24s  kubelet            Started container trace-agent  
  Normal  Started    3m23s  kubelet            Started container process-agent  
  Normal  Started    3m23s  kubelet            Started container system-probe  
  Normal  Started    3m26s  kubelet            Started container init-volume  
  Normal  Started    3m26s  kubelet            Started container init-config  
  Normal  Started    3m25s  kubelet            Started container seccomp-setup  
  Normal  Started    3m24s  kubelet            Started container agent  
  Normal  Started    3m24s  kubelet            Started container trace-agent  
  Normal  Started    3m23s  kubelet            Started container process-agent  
  Normal  Started    3m23s  kubelet            Started container system-probe  
  Normal  Started    3m27s  kubelet            Started container cluster-agent  
  Normal  Started    46m   kubelet            Started container datadog-operator  
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
- Uninstall the operator  
  ```
  helm uninstall dd-operator  
  ```
- Get pods  
  ```
  kubectl get po  
  ```
