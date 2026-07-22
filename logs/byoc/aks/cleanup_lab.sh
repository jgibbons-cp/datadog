#!/bin/bash

source ./.env

# can't reuse storage name for 14 days without UI purge so need to grab it
byoc_logs_storage_account=".byoc_logs_storage_account"
BYOC_LOGS_STORAGE_ACCOUNT=$(cat $(pwd)/"$byoc_logs_storage_account")
rm $byoc_logs_storage_account

az storage account delete -n "$BYOC_LOGS_STORAGE_ACCOUNT" -g "$BYOC_LOGS_RESOURCE_GROUP" --yes

app_id=$(az ad app list --filter "displayName eq '$BYOC_LOGS_STORAGE_ACCOUNT'" --query "[].appId" -o tsv)
if [[ -n "$app_id" ]]; then
  az ad app delete --id "$app_id"
fi

app_id=$(az ad app list --filter "displayName eq 'byoclogs'" --query "[].appId" -o tsv)
if [[ -n "$app_id" ]]; then
  az ad app delete --id "$app_id"
fi

az aks delete --resource-group "$BYOC_LOGS_RESOURCE_GROUP" --name "$BYOC_LOGS_CLUSTER_NAME" --yes

az group delete --name "$BYOC_LOGS_RESOURCE_GROUP" --yes