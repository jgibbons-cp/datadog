Nginx Ingress Controller
--

The [Nginx Ingress Controller](https://docs.nginx.com/nginx-ingress-controller/) is "an implementation of a Kubernetes Ingress Controller for NGINX and NGINX Plus..... The Ingress is a Kubernetes resource that lets you configure an HTTP load balancer for applications running on Kubernetes, represented by one or more Services. Such a load balancer is necessary to deliver those applications to clients outside of the Kubernetes cluster."  
  
- [Instructions](https://learn.microsoft.com/en-us/azure/aks/ingress-basic?tabs=azure-cli#basic-configuration)  
- Managed k8s used - AKS  
- Application used in example - [knote](https://github.com/jgibbons-cp/datadog/tree/main/kubernetes/nodejs_tracing/dockerfile_configuration)  
  - Deploy:  
    ```  
    kubectl create -f knote.yaml  
    kubectl create -f knote_clusterip_svc.yaml  
    kubectl create -f mongo.yaml  
    ```  
    The service is a ClusterIP service so it is only reachable from inside the cluster.  To confirm the application is running:  
    ```  
    kubectl port-forward deploy/knote 8080:3000  
    ```  
    Navigate to:  
    ```
    http://localhost:8080  
    ```  
- Deploy Nginx ingress with [helm](https://helm.sh/):  
  ```  
  NAMESPACE=nginx-ingress  
  
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx  
  helm repo update  
  
  # IMPORTANT --set controller.service.loadBalancerSourceRanges="{<YOUR_EXTERNAL_IP/32>}" restricts access to the public 
  # IP from just your IP.  Do not leave it open to 0.0.0.0
  helm install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace $NAMESPACE --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz  --set controller.service.loadBalancerSourceRanges="{<YOUR_EXTERNAL_IP/32>}"
  ```  

- Get the external IP of the load balancer  
  ```  
  kubectl get service -n nginx-ingress  
  ```  
  The external IP will be under EXTERNAL-IP for the ingress-nginx-controller.  
    
- Add a DNS address to the pubic IP of the load balancer.  Go to the Azure portal and search for your IP address.  Go to the public IP address option, configuration and add a 'DNS name label (optional)'  
  
- Deploy an Ingress  
  In knote-ingress.yaml update <FQDN> to your DNS name.  
  
  ```  
  kubectl create -f knote-ingress.yaml  
  ```  
  
- Hit the app  
  ```  
  http://<FQDN>  
  ```  
