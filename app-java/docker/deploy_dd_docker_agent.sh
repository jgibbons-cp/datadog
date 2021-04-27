#!/bin/bash

if [ "$DD_API_KEY" == "" ]
then
  echo "Populate DD_API_KEY... exiting..."
  exit -1
fi

source ./create_network.sh

osx="Darwin"
os=$(uname)
npm_args=""

#network performance monitoring not supported on OSX - https://docs.datadoghq.com/network_monitoring/performance/

if [ "$os" != "$osx" ]
then
  npm_args="-e DD_SYSTEM_PROBE_ENABLED=true -v /sys/kernel/debug:/sys/kernel/debug --security-opt apparmor:unconfined --cap-add=SYS_ADMIN --cap-add=SYS_RESOURCE --cap-add=SYS_PTRACE --cap-add=NET_ADMIN --cap-add=IPC_LOCK"
fi

#Environment variables - https://docs.datadoghq.com/tracing/setup_overview/setup/java/?tab=containers
# DD_ENV - Your application environment (e.g. production, staging, etc.). Available for versions 0.48+.
# DD_VERSION - Your application version (e.g. 2.5, 202003181415, 1.3-alpha, etc.). Available for versions 0.48+.
# DD_APM_NON_LOCAL_TRAFFIC - for JMX metrics from containers - statsd port 8125 needs to be open too - DD_DOGSTATSD_NON_LOCAL_TRAFFIC
# DD_LOGS_ENABLED - enable the logging agent
# DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL - collect container logs
# DD_PROCESS_AGENT_ENABLED - love process collection

#deploy datadog agent
docker run -d --network $lab_network --name dd-agent -v /var/run/docker.sock:/var/run/docker.sock:ro -v /proc/:/host/proc/:ro -v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro -e DD_API_KEY=$DD_API_KEY -e DD_ENV=lab -e DD_VERSION=.01 -e DD_APM_NON_LOCAL_TRAFFIC=true -e DD_LOGS_ENABLED=true -e DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true -v /etc/passwd:/etc/passwd:ro -e DD_PROCESS_AGENT_ENABLED=true -e DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true $npm_args gcr.io/datadoghq/agent:7
