#!/bin/bash

CLUSTER_NAME="kind-k8"

kind delete cluster --name "$CLUSTER_NAME" --kubeconfig config

#does not support merge of configs
if test -f "config"; then
  rm config
fi
