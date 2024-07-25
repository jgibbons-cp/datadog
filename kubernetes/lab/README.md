Datadog Kubernetes Agent Installation - Operator
--

Common items:  
  
- ```  
  kubectl get pods  
  ```  
  If this does not return anything set your KUBECONFIG to your config.  
  ```
  export KUBECONFIG=/path/to/config  
- ```
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
- Let's install this in another namespace. Create it and switch to it.
  ```  
  kubectl create ns datadog && kubectl config set-context --current --namespace=datadog
  ```  
- Create a secret  
  ```
  kubectl create secret generic datadog-secret --from-literal api-key=<key> --from-literal app-key=<key>  
  ```  
- Click into the operator specific [instructions](https://github.com/jgibbons-cp/datadog/tree/main/kubernetes/lab/operator)  
