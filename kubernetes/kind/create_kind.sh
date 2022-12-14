#!/usr/bin/env bash

#use cmd to see if docker is running
docker ps > /dev/null

if [ "$?" -eq "1" ];
then
  echo "docker is not running..."
  exit -1
fi

CLUSTER_NAME="kind-k8"

#does not support merge of configs
if test -f "config"; then
  rm config
fi

#create
kind create cluster --name "$CLUSTER_NAME" --kubeconfig config --config config.yaml
