Datadog Kubernetes Agent Installation
--

Common items:  
  
- Create a cluster with [minikube](https://minikube.sigs.k8s.io/docs/), [kind](https://kind.sigs.k8s.io/) or another method of your choice.  If you use a method other than minikube or kind you can install ebpf supported features too (network performance monitoring and security).  
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
  
Choose your method and have fun :)  
