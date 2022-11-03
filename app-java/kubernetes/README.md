Deploy Java App on Kubernetes
--

Basic app that has a servlet front-end and talks to MySQL.  This simply deploys
on Kubernetes that incudes Datadog RUM, APM and application security.  

Manifests
--

1) app-java.yaml - manifest to deploy app  

2) mysql_ja.yaml - manifest to deploy MySQL  

3) app_java_service.yaml - a service to hit the app via a LoadBalancer  

Deploy  
---

1) Deploy Datadog agent in cluster  

2) Create secret for RUM replacing the values with your keys  

 ```
 kubectl create secret generic dd-rum-tokens --from-literal CLIENT_TOKEN=TOKEN --from-literal APPLICATION_ID=APPID
 ```  

3) Deploy app ```kubectl create -f app-java.yaml```

2) Deploy MySQL ```kubectl create -f mysql_ja.yaml```  

3) Deploy service ```kubectl create -f app_java_service.yaml```  
  
4) Configure the load  balancer rules to accept traffic from your IP

Hit it at ```http://LoadBalancer:8080/app-java-0.0.1-SNAPSHOT/```
and look at traces.  
