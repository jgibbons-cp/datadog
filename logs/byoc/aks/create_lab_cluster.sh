#!/bin/bash

az > /dev/null 2>&1 || true
if [[ "$?" -ne "0" ]]; then
  echo "Install the azure cli... exiting"
fi

logged_in_metadata=$(az account show 2>&1)
echo "$logged_in_metadata" | grep "No subscription found. Run 'az account set'"
if [[ "$?" -eq "0" ]]; then
  echo "Log into the azure cli... exiting"
fi

# need Microsoft.ContainerService resource provider to create cluster
ms_container_svc_registered="az provider show 
--namespace Microsoft.ContainerService --query 
registrationState"

if ! $ms_container_svc_registered > /dev/null 2>&1; then
  echo "Registering the Microsoft.ContainerService resource provider"
  az provider register --namespace Microsoft.ContainerService
fi

# get env
source ./.env

# create resource group
create_resource_group="az group create --name $BYOC_LOGS_RESOURCE_GROUP --location $BYOC_LOGS_LOCATION"

if ! $create_resource_group > /dev/null 2>&1; then
  echo "az group create failed... exiting..."
  exit 1
else
  echo "Created resource group $BYOC_LOGS_RESOURCE_GROUP..."
fi

# create cluster
az aks create \
  --resource-group "$BYOC_LOGS_RESOURCE_GROUP" \
  --name "$BYOC_LOGS_CLUSTER_NAME" \
  --node-count "$BYOC_LOGS_NODE_COUNT" \
  --node-vm-size "$BYOC_LOGS_AKS_NODE_SIZE" \
  --ssh-access disabled

# get kubeconfig
KUBECONFIG="$(pwd)/config"

# make sure it is not mixed up with cluster of same name e.g. eks
if [ -f "$KUBECONFIG" ]; then
    mv "$KUBECONFIG" "$KUBECONFIG"_$(date +%s).bk
    echo "Backing up kubeconfig to ${KUBECONFIG}_$(date +%s).bk"
fi

az aks get-credentials --resource-group "$BYOC_LOGS_RESOURCE_GROUP" \
  --name "$BYOC_LOGS_CLUSTER_NAME" -f $KUBECONFIG

if [ $? -ne 0 ]; then
    exit 1
fi

export KUBECONFIG="$KUBECONFIG"
