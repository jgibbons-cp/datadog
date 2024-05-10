Integration Testing K8 WebApp Deployments
--  

Requirements  
-  

1) pip - gitpython  
2) pip - kubernetes  
3) pip - python-terraform  
4) pip - datadog-api-client  
5) npm

Files  
-  

1) cicd_functions.py - shared functions  

2) app_java.py - dev environment code for the app-java application.  Shows a
dev like environment that brings up an aks cluster, installs the Datadog agents
, tests the agent containers, deploys the app and related services, tests the
containers, does a Datadog browser test, sends success or failure to Datadog
via logs, and deletes the cluster.  Is for a dev environment where a dev can
test prior to merging into main.  
