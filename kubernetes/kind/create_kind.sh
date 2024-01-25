#!/bin/bash

#use cmd to see if docker is running and get result string for later
if ! rv=$(docker ps 2> /dev/null);
then
  echo "docker is not running... exiting..."
  exit 1
fi

CLUSTER_NAME="kind-k8"

#don't create if running
if ! echo $rv | grep -E 'kind-k8-worker.*kind-k8-control-plane|kind-k8-control-plane.*kind-k8-worker' > /dev/null;
then
  #does not support merge of configs
  if test -f "config"; then
    rm config
  fi

  #create
  if ! kind create cluster --name "$CLUSTER_NAME" --kubeconfig config --config config.yaml
  then
    echo "Cluster failed to start... cleaning up and exiting..."
    #seems to fail when start again even though no containers created
    sh delete_kind.sh 2> /dev/null
    exit 1
  fi
fi
