#!/bin/bash
set -euo pipefail

source ./.env

# can't reuse storage name for 14 days without UI purge so need to grab it
byoc_logs_storage_account=".byoc_logs_storage_account"
BYOC_LOGS_STORAGE_ACCOUNT=byoclogs-$(date +%s)
BYOC_LOGS_STORAGE_ACCOUNT="${BYOC_LOGS_STORAGE_ACCOUNT//-/}"
echo $BYOC_LOGS_STORAGE_ACCOUNT > $(pwd)/$byoc_logs_storage_account

az storage account create \
  --name "$BYOC_LOGS_STORAGE_ACCOUNT" \
  --resource-group "$BYOC_LOGS_RESOURCE_GROUP" \
  --location "$BYOC_LOGS_LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2

az storage account show \
  --name "$BYOC_LOGS_STORAGE_ACCOUNT" \
  --resource-group "$BYOC_LOGS_RESOURCE_GROUP" \
  --query "provisioningState" \
  --output none

set +e
while [[ "$?" -ne "0" ]]; do
    echo "Waiting for storage to be created..."
    sleep 1
    az storage account show \
      --name "$BYOC_LOGS_STORAGE_ACCOUNT" \
      --resource-group "$BYOC_LOGS_RESOURCE_GROUP" \
      --query "provisioningState" \
      --output none
done
set -e

az storage container create \
    --name "$BYOC_LOGS_STORAGE_CONTAINER" \
    --account-name "$BYOC_LOGS_STORAGE_ACCOUNT" \
    --auth-mode login

app_id=$(az ad app list --display-name byoclogs --query "[].appId" -o tsv)
if [[ -n "$app_id" ]]; then
  az ad app delete --id "$app_id"
fi

az ad app create --display-name byoclogs

# get subscription id
SUBSCRIPTION_ID=$(az account show --query "id" --output tsv)

# create sp
service_principal=$(az ad sp create-for-rbac \
  --name "$BYOC_LOGS_STORAGE_ACCOUNT" \
  --role "Storage Blob Data Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$BYOC_LOGS_RESOURCE_GROUP")

SERVICE_PRINCIPAL_APPLICATION_ID=$(echo "$service_principal" | jq -r '.[keys_unsorted[0]]')
SERVICE_PRINCIPAL_SECRET=$(echo "$service_principal" | jq -r '.[keys_unsorted[2]]')
SERVICE_PRINCIPAL_TENANT_ID=$(echo "$service_principal" | jq -r '.[keys_unsorted[3]]')

# use to debug connection to storage/permission issues
#echo AZURE_TENANT_ID="$SERVICE_PRINCIPAL_TENANT_ID"
#echo AZURE_CLIENT_ID="$SERVICE_PRINCIPAL_APPLICATION_ID"
#echo AZURE_CLIENT_SECRET="$SERVICE_PRINCIPAL_SECRET"

#echo "kubectl create secret generic azure-blob-sp-secret \
#  --from-literal=AZURE_TENANT_ID=$SERVICE_PRINCIPAL_TENANT_ID   \
#  --from-literal=AZURE_CLIENT_ID=$SERVICE_PRINCIPAL_APPLICATION_ID   \
#  --from-literal=AZURE_CLIENT_SECRET=$SERVICE_PRINCIPAL_SECRET   \
#  --from-literal=AZURE_STORAGE_ACCOUNT_NAME=$BYOC_LOGS_STORAGE_ACCOUNT"

# have access to info for byoclogs config
cp datadog-values.yaml datadog-values-modified.yaml
sed -i '' "s/TENANT_ID/$SERVICE_PRINCIPAL_TENANT_ID/" datadog-values-modified.yaml
sed -i '' "s/CLIENT_ID/$SERVICE_PRINCIPAL_APPLICATION_ID/" datadog-values-modified.yaml
sed -i '' "s/STORAGE_ACCOUNT/$BYOC_LOGS_STORAGE_ACCOUNT/" datadog-values-modified.yaml
NAMESPACE=byoclogs
kubectl create namespace $NAMESPACE

kubectl create secret generic byoclogs-storage \
  --from-literal storage-key="$SERVICE_PRINCIPAL_SECRET" \
  -n $NAMESPACE

scope="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$BYOC_LOGS_RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$BYOC_LOGS_STORAGE_ACCOUNT/blobServices/default/containers/$BYOC_LOGS_STORAGE_CONTAINER"

# assign role for rw
az role assignment create \
    --role "Storage Blob Data Contributor" \
    --assignee "$SERVICE_PRINCIPAL_APPLICATION_ID" \
    --scope "$scope"

az storage account update \
    --name "$BYOC_LOGS_STORAGE_ACCOUNT" \
    --resource-group "$BYOC_LOGS_RESOURCE_GROUP" \
    --default-action Deny

az storage account network-rule add \
    --account-name "$BYOC_LOGS_STORAGE_ACCOUNT" \
    --resource-group "$BYOC_LOGS_RESOURCE_GROUP" \
    --ip-address "$(curl -4 ifconfig.me)"

aks_rg=$(az aks show --resource-group "$BYOC_LOGS_RESOURCE_GROUP" --name "$BYOC_LOGS_CLUSTER_NAME" --query nodeResourceGroup -o tsv)
while [[ -z "$aks_rg" ]]; do
  echo "Waiting for AKS metadata for firewall rule..."
  sleep 1
  aks_rg=$(az aks show --resource-group "$BYOC_LOGS_RESOURCE_GROUP" --name "$BYOC_LOGS_CLUSTER_NAME" --query nodeResourceGroup -o tsv)
done

NODE_RG=$(az aks show --resource-group "$BYOC_LOGS_RESOURCE_GROUP" --name "$BYOC_LOGS_CLUSTER_NAME" --query nodeResourceGroup -o tsv)
aks_vnet=$(az network vnet list --resource-group "$NODE_RG" --query "[0].name" -o tsv)
aks_default_subnet=aks-subnet

az network vnet subnet update \
  --resource-group "$aks_rg" \
  --vnet-name "$aks_vnet" \
  --name "$aks_default_subnet" \
  --service-endpoints "Microsoft.Storage"

SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$aks_rg" \
  --vnet-name "$aks_vnet" \
  --name "$aks_default_subnet" \
  --query id \
  --output tsv)

az storage account network-rule add \
  --resource-group "$BYOC_LOGS_RESOURCE_GROUP" \
  --account-name "$BYOC_LOGS_STORAGE_ACCOUNT" \
  --subnet "$SUBNET_ID"
