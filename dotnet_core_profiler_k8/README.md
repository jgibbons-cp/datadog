dotnet_core_profiler_k8
--

Example of the Linux .NET Core profiler using a sample .NET Core application
from MS in K8.  

Files
--

- Dockerfile - used to create a Docker image that takes the base image and
copies the profiler artifacts into /opt/datadog/profiler  You can build it or
just pull if from jenksgibbons/aspnc  

- aspnc.yaml - pod definition file  

Based on Datadog
[documentation](https://docs.datadoghq.com/agent/kubernetes/apm/?tab=daemonset),
the following environment variables have been added to the yaml:  

  -  ```env:
          - name: DD_AGENT_HOST
            valueFrom:
              fieldRef:
                fieldPath: status.hostIP
      ```

Based on the Linux .NET Core profiler documentation, the following environment
variables have been added and need need to be configured based on the profiler
documentation:

  * CORECLR_ENABLE_PROFILING
  * CORECLR_PROFILER_PATH_64
  * name: CORECLR_PROFILER
  * name: LD_LIBRARY_PATH
  * name: LD_PRELOAD
  * name: DD_ENV
  * name: DD_SERVICE
  * name: DD_VERSION
  * name: DD_AGENT_HOST
      valueFrom:
        fieldRef:
          apiVersion: v1
          fieldPath: status.hostIP

- aspnc_service.yaml - service definition file

- datadog-agent.yaml

Use a version of the Datadog K8 agent that includes APM from
[here](https://docs.datadoghq.com/agent/kubernetes/?tab=daemonset) like
[such](https://docs.datadoghq.com/resources/yaml/datadog-agent-apm.yaml)  

Configure the secret for the API key, or rather create the secret first so it
is not in the yaml in base64.  

Based on Datadog
[documentation](https://docs.datadoghq.com/agent/kubernetes/apm/?tab=daemonset),
the following environment variables have been added to the yaml:  

  - ```# (...)
      ports:
        # (...)
        - containerPort: 8126
          hostPort: 8126
          name: traceport
          protocol: TCP
       # (...)```

  - ```# (...)
      env:
        # (...)
        - name: DD_APM_ENABLED
          value: 'true'
        - name: DD_APM_NON_LOCAL_TRAFFIC
          value: "true"
       # (...)```

Configuration
--

- In aspnc.yaml configure the environment variables with the values from the
documentation.
- In the agent yaml configure the agent

Apply
--

- ```kubectl create -f datadog-agent-apm.yaml```

You should see this with ```kubectl get pods```  You can confirm that the tracer
agent is listening with this:  
  
datadog-agent-kzf57   3/3     Running   0          30s  
datadog-agent-x5pk2   3/3     Running   0          30s  

To confirm the tracer is running do this:  

```kubectl exec -it <pod_name> -- agent status```  

and look for APM Agent in the output.  

- ```kubectl create -f aspnc.yaml```  
- ```kubectl create -f aspnc_service.yaml```  

Send traffic and look at the profiles.  
