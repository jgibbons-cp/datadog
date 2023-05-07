Nginx Ingress Controller
--

The [Nginx Ingress Controller](https://docs.nginx.com/nginx-ingress-controller/) is "an implementation of a Kubernetes Ingress Controller for NGINX and NGINX Plus..... The Ingress is a Kubernetes resource that lets you configure an HTTP load balancer for applications running on Kubernetes, represented by one or more Services. Such a load balancer is necessary to deliver those applications to clients outside of the Kubernetes cluster."  
  
- [Instructions](https://learn.microsoft.com/en-us/azure/aks/ingress-basic?tabs=azure-cli#basic-configuration)  
- Managed k8s used - AKS which is where these instrutions were tested  
- Knote application used in example - [knote](https://github.com/jgibbons-cp/datadog/tree/main/kubernetes/nodejs_tracing/dockerfile_configuration) or relative to this repo ```../../kubernetes/nodejs_tracing/dockerfile_configuration/```  
  - Deploy NOTE - change image from ```<repo>/<image>:<tag>``` to jenksgibbons/knote:no_tracer:  
    ```  
    pushd ../../kubernetes/nodejs_tracing/dockerfile_configuration/   
    kubectl create -f knote.yaml  
    kubectl create -f knote_clusterip_svc.yaml  
    kubectl create -f mongo.yaml  
    popd  
    ```  
    The service is a ClusterIP service so it is only reachable from inside the cluster.  NOTE: we could use a load balancer to 
    reach the application externally as well rather than an ingress.  To confirm the application is running:  
    ```  
    kubectl port-forward deploy/knote 8080:3000  
    ```  
    Navigate to:  
    ```
    http://localhost:8080  
    ```  
- Deploy Nginx ingress with [helm](https://helm.sh/)  
  IMPORTANT ```--set controller.service.loadBalancerSourceRanges="{YOUR_EXTERNAL_IP/32}"``` restricts access to the public  
  IP of the load balancer from just your IP.  Do not leave it open to 0.0.0.0:  
  ```  
  NAMESPACE=ingress-nginx  
  
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx  
  helm repo update  
  
  helm install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace $NAMESPACE --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz  --set controller.service.loadBalancerSourceRanges="{YOUR_EXTERNAL_IP/32}"
  ```  

- Get the external IP of the load balancer  
  ```  
  kubectl get service -n ingress-nginx  
  ```  
  The external IP will be under EXTERNAL-IP for the ingress-nginx-controller.  
    
- Add a DNS address to the pubic IP of the load balancer.  Go to the Azure portal and search for your IP address.  Go to the public IP address option, configuration and add a 'DNS name label (optional)'  
  
- Deploy an Ingress  
  In application_ingress.yaml update <FQDN> to your DNS name.  
  
  ```  
  kubectl create -f application_ingress.yaml  
  ```  
  
- Hit the app  
  ```  
  http://<FQDN>  
  ```  

- Create another application, from [here](https://github.com/jgibbons-cp/datadog/tree/main/app-java/kubernetes) or relative 
  to this repo ```../../app-java/kubernetes/```.  
  
- Create a secret for the application. NOTE: get the values from a Datadog RUM application or put fake data just to test.  
  ```  
  kubectl create secret generic dd-rum-tokens --from-literal CLIENT_TOKEN=TOKEN --from-literal APPLICATION_ID=APPID  
  ```  
  
- Deploy the application  
  ```  
  pushd ../../app-java/kubernetes/  
  kubectl create -f app-java.yaml  
  kubectl create -f app_java_clusterip_svc.yaml  
  kubectl create -f mysql_ja.yaml  
  popd  
  ```  
  
- NOTE: you could hit this as well using a port-forward, it listens on 8080.  You could also use a load balancer.  If you used 
  load balancers you would need two and the FQDNs of the applications would be different.  It depends on what you want, but 
  this provides an alternative where you can reach them with one load balancer and one FQDN.  

- The [ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) has already been configured for this app 
  as well.  A few notes:  
  ```  
    # FQDN of the external load balancer  
    - host: <label>.<region>.cloudapp.azure.com
    http:
      paths:
      - backend:
          service:
            # kubernetes ClusterIP service to reach the app
            name: knote
            port:
              # port on load balancer that will forward the traffic to the service
              number: 80
        # path of app
        path: /
        pathType: Prefix
  ```  
    
  - Hit the other app at ```http://<FQDN>/app-java-0.0.1-SNAPSHOT/```