Deploy Java App on Kubernetes
--

Basic app that has a servlet front-end and talks to MySQL.  This simply deploys
on Kubernetes that incudes Datadog RUM, APM and application security.  

Manifests
--

1) app-java.yaml - manifest to deploy app  

2) ../kubernetes/mysql_ja.yaml - manifest to deploy MySQL  

3) ../kubernetest/app_java_service.yaml - a service to hit the app via a LoadBalancer  

Deploy  
---

1) Deploy Datadog agent in cluster  

2) Create secret for RUM replacing the values with your keys  

 ```
 kubectl create secret generic dd-rum-tokens --from-literal CLIENT_TOKEN=TOKEN --from-literal APPLICATION_ID=APPID
 ```  

3) Deploy app ```kubectl create -f app-java.yaml```  
  
You can see if the init container ran in the container view of app-java.  Look at the container 
to see if the init container ran and terminated.  
  
2) Deploy MySQL ```kubectl create -f ../kubernetes/mysql_ja.yaml```  

3) Deploy service (NOTE: replace <your_external_ip> with your external IP for the load balancer)
```kubectl create -f ../kubernetes/app_java_service.yaml```  
  
4) Hit it at ```http://LoadBalancer:8080/app-java-0.0.1-SNAPSHOT/``` and look at traces.  
  
Logs  (log4j2 only)
--  
  
1) By default, the app logs to STDOUT and correlates traceid/logs  
  
2) To use a file and raw format  
  
a) app-java.yaml  
  
  - comment block after ```# log to stdout```  
  - uncomment block after ```log to file rather than stdout```  
  - uncomment volumes and volumeMounts  
  - add the volumes and volumeMounts to the agent  
  
b) log4j2.xml  
  
  - comment ```<!-- Uncomment for logging to stdout-->```  
  - uncomment ```<!-- uncomment to use file raw format-->```  
  - comment ```<!-- Uncomment for logging to stdout-->``` in ```<Loggers>```  
  - uncomment ```<!-- Uncomment for logging to file-->``` in ```<Loggers>```  

