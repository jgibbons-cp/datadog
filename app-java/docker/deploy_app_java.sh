#!/bin/bash

#create network if does not exist
source ./create_network.sh

#system properties and environment variables
# Tracing Java applications - https://docs.datadoghq.com/tracing/setup_overview/setup/java/?tab=containers
# Unified service tagging - https://docs.datadoghq.com/getting_started/tagging/unified_service_tagging/?tab=kubernetes
# dd.service - https://docs.datadoghq.com/tracing/setup_overview/setup/java/?tab=containers
# dd.version - Your application version (e.g. 2.5, 202003181415, 1.3-alpha, etc.). Available for versions 0.48+.
# dd.env = Your application environment (e.g. production, staging, etc.). Available for versions 0.48+.
# dd.logs.injection - Enabled automatic MDC key injection for Datadog trace and span IDs.
# dd.profiling.enabled - profiler
# DD_AGENT_HOST = Hostname for where to send traces to. If using a containerized environment, configure this to be the host IP. Points to the agent container.
# DD_TRACE_AGENT_PORT - Port number the Agent is listening on for configured host.

#deploy app-java
docker run -d --network $lab_network -p 8080:8080 --name TomcatContainer -e JAVA_OPTS='-javaagent:/usr/local/tomcat/lib/dd-java-agent.jar -Ddd.service=java-app -Ddd.version=.01 -Ddd.env=lab -Ddd.logs.injection=true -Ddd.profiling.enabled=true -XX:FlightRecorderOptions=stackdepth=256' -e DD_AGENT_HOST=dd-agent -e DD_TRACE_AGENT_PORT=8126 -e CLIENT_TOKEN=<CLIENT_TOKEN> -e APPLICATION_ID=<APPLICATION_ID> jenksgibbons/app-java
