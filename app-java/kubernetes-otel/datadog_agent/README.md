Deploy Java App on Kubernetes with OTEL Tracer and Datadog Agent
--

Basic app that has a servlet front-end and talks to MySQL.  This simply deploys
on Kubernetes and incudes Datadog RUM, APM, database monitoring and application
 security.  

Build
--

If you need to build the container use ```../../docker/build.sh``` setting
```
OTEL=1
```  

Manifests
--

1) app-java.yaml - manifest to deploy app and a service to hit the app via a
LoadBalancer  

2) mysql_ja.yaml - manifest to deploy MySQL  

Deploy  
---

1) Deploy Datadog agent in cluster.  [Enable](https://docs.datadoghq.com/tracing/trace_collection/open_standards/otlp_ingest_in_the_agent/?tab=kuberneteshelmvaluesyaml#enabling-otlp-ingestion-on-the-datadog-agent)
the gRPC OTEL listener in the agent.

2) Create secret for RUM replacing the values with your keys  

 ```
 kubectl create secret generic dd-rum-tokens --from-literal CLIENT_TOKEN=TOKEN --from-literal APPLICATION_ID=APPID
 ```  

3) Deploy app ```kubectl create -f app-java.yaml```

2) Deploy MySQL ```kubectl create -f ../../kubernetes/mysql_ja.yaml```  

3) Configure the load  balancer rules to accept traffic from your IP

Hit it at ```http://LoadBalancer:8080/app-java-0.0.1-SNAPSHOT/```
and look at traces.  
