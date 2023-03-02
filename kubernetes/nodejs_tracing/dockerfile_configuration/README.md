Example of Configuring Datadog APM and Profiling from a dockerfile
--

This is a sample app pulled from [knote-js](https://github.com/learnk8s/knote-js).  This will outline how to configure APM, profiling and runtime metrics from the application dockerfile for deployment on Kubernetes.  The only changes related to Datadog are in the dockerfile with none in the application manifest.  For other ways of implementation see Datadog [APM](https://docs.datadoghq.com/tracing/trace_collection/dd_libraries/nodejs/?tab=containers), [profiling](https://docs.datadoghq.com/profiler/enabling/nodejs/?tab=environmentvariables) and [runtime metrics](https://docs.datadoghq.com/tracing/metrics/runtime_metrics/nodejs/?tab=environmentvariables).  
  
Files
--

1) dockerfile - container configuration and noted options  
a) This environment variable configures communication with the agent service.  To get the name of your service see [services](https://app.datadoghq.com/orchestration/overview/service)  NOTE: requires Kubernetes v1.22+ as uses ```internalTrafficPolicy: Local``` so the pod always talks to the agent pod on the same node to ensure infrastructure tags are accurate.  
- ENV DD_AGENT_HOST="<agent_service_name>"  
b) correlation tags  
- ENV DD_SERVICE="<name_of_service_to_be_traced>"  
- ENV DD_VERSION="<version_of_service_to_be_traced>"  
- ENV DD_ENV="<env_of_service_to_be_traced>"  
  
Once the options are configured, build and push (NOTE: requires you to pull repo and ```cd knote-js/01``` to build):  
```  
docker build -t <repo>/<image> .;docker push <repo>/<image>  
```  
  
2) knote.yaml - deployment file with no Datadog related configuration  
  
3) mongo.yaml - deployment file with no Datadog related configuration  
  
4) Deploy  
- update ```<repo>/<image>``` in knote.yaml with your container  
- update ```<ip>``` with your IP so you can access the app via the loadbalancer  
- ```kubectl create -f .```  
  
5) Hit the app http://<loadbalancer_ip>  
  
6) Look at [traces](https://app.datadoghq.com/apm/traces), [profiles](https://app.datadoghq.com/profiling/search), and [runtime metrics](https://app.datadoghq.com/dash/integration/30269/nodejs-runtime-metrics) or in the metrics section of a trace panel.  
  
Have fun!  

