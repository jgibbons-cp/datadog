#!/bin/bash

#create network if does not exist
source ./create_network.sh

#deploy app-java
docker run --network $lab_network -p 127.0.0.1:8080:8080 --name TomcatContainer -e JAVA_OPTS='-javaagent:/usr/local/tomcat/lib/dd-java-agent.jar -Ddd.service=java-app -Ddd.version=.01 -Ddd.env=lab -Ddd.logs.injection=true -Ddd.profiling.enabled=true -XX:FlightRecorderOptions=stackdepth=256' -e DD_AGENT_HOST=dd-agent -e DD_TRACE_AGENT_PORT=8126 jgibbons-cp/app-java
