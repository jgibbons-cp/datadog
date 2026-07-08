#!/bin/bash

source ./.env

az storage account delete -n "$BYOC_LOGS_STORAGE_ACCOUNT" -g "$BYOC_LOGS_RESOURCE_GROUP" --yes

service_principal=$(az ad sp list --filter "displayName eq 'byoclogs'" --query "[].appId" -o tsv)
app_id=$(az ad app list --display-name byoclogs --query "[].appId" -o tsv)
if [[ -n "$app_id" ]]; then
  az ad sp delete --id "$service_principal"
  az ad app delete --id "$app_id"
fi

az aks delete --resource-group "$BYOC_LOGS_RESOURCE_GROUP" --name "$BYOC_LOGS_CLUSTER_NAME" --yes

az group delete --name "$BYOC_LOGS_RESOURCE_GROUP" --yes