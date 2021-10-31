Build an ASPNet48 MVC Windows Server Core LTSC 2019 App and Trace with Datadog
--

Files
--

1) Directory - aspnet48_mvc_win_server_core_ltsc_2019_app: the app we will build
to execute and trace

2) aspnet48_mvc_win_server_core_ltsc_2019_app\Dockerfile

   This will build the container we need to execute the app and start the tracer.

   A few notes about the build as this is a bit different from what I have seen on
   Linux:

- #base images in Dockerfile and notes  
  FROM mcr.microsoft.com/dotnet/framework/sdk:4.8 AS build  
  FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019 AS runtime  

  From [Datadog documentation](https://docs.datadoghq.com/agent/troubleshooting/windows_containers/)
  note the following:

  Containerized Windows Applications Monitoring requires Datadog Agent 7.19+.

  The supported OS versions are Windows Server 2019 (LTSC) and version 1909 (SAC).

  Hyper-V isolation mode is not supported.

  Host metrics for disk, IO, and network are disabled. They are not supported by Windows Server, hence the Agent Checks are disabled by default.

  Live processes do not appear in containers (except for the Datadog Agent).

- NOTE: the tracer will be installed in the container during the build and started

- The final line has a script named Startup.ps1 that is referenced.

  ENTRYPOINT ["powershell.exe", "C:\\inetpub\\wwwroot\\Startup.ps1"]

3) aspnet48_mvc_win_server_core_ltsc_2019_app\Startup.ps1

   This first line:

   ```
   Set-Content -Path 'C:\\inetpub\\wwwroot\\datadog.json' -Value "{ `"DD_AGENT_HOST`": `"$env:DD_AGENT_HOST`" } "
   ```

   will set the IP for the agent container.  I need to look into this, but I think
   this can also just be done with a network the containers share making this
   unecessary, but for now this works and I will investigate later.

   Next, it stops/restarts IIS then starts the application.

Build
--

To build the container run:

```
docker build -t <image_name> .
```

Then push it to a repository or run it locally.

Run
--

1) Create a network for the containers to talk to each other

   ```
   docker network create --driver <network_name>
   ```

2) Run the Datadog agent  
--

   ```
    docker run -d --network <network_name> --name dd-agent -e DD_API_KEY=<api_key>
     -e DD_ENV="<env>" -e DD_SERVICE="<service>" -e DD_VERSION="<version>"
      -e DD_APM_ENABLED="true" -e DD_APM_NON_LOCAL_TRAFFIC="true"
      -v \\.\pipe\docker_engine:\\.\pipe\docker_engine gcr.io/datadoghq/agent
   ```

   DD_API_KEY - Datadog API key
   [Unified service tagging](https://docs.datadoghq.com/getting_started/tagging/unified_service_tagging/?tab=kubernetes)
   DD_ENV - Datadog environment tag
   DD_SERVICE - Datadog service tag
   DD_VERSION - Datadog Version tag
   DD_APM_ENABLED="true" - enable APM (application performance monitoring)
   DD_APM_NON_LOCAL_TRAFFIC="true" - enable tracing from other containers

3) Run the application

   ```
    docker run -d --network <network_name> -p 80:80 -e
    DD_APM_NON_LOCAL_TRAFFIC="true" -e DD_ENV="<env>" -e DD_SERVICE="<service>"
    -e DD_VERSION="<version>" -e DD_APM_ENABLED="true" -e
    DD_AGENT_HOST=dd-agent #name of agent container -e DD_HOSTNAME="<hostname>"
    -e DD_TRACE_AGENT_PORT=8126 <image>
   ```
   DD_APM_NON_LOCAL_TRAFFIC="true"  - enable tracing from other containers
   DD_AGENT_HOST=dd-agent - agent host, go to name of agent container
   DD_HOSTNAME - hostname if not automatically picked up
   DD_TRACE_AGENT_PORT=8126 - trace port

4) Hit the app to get some traffic

   In your browser hit ```http://localhost``` and click around

5) Go to APM in Datadog to see traces - ```https://app.datadoghq.com/apm/traces```

Have fun!
