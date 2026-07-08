#!/bin/bash
set -euo pipefail

source ./.env

# get egress IP from cluster
ids=$(az aks show -g "$BYOC_LOGS_RESOURCE_GROUP" -n "$BYOC_LOGS_CLUSTER_NAME" \
  --query networkProfile.loadBalancerProfile.effectiveOutboundIPs[].id -o tsv)
cluster_egress_ip=$(az network public-ip show --ids "$ids" \
  --query ipAddress -o tsv)

# create db
az postgres flexible-server create --resource-group "$BYOC_LOGS_RESOURCE_GROUP" \
  --name "$BYOC_LOGS_POSTGRES_NAME" --location "$BYOC_LOGS_LOCATION" \
  --admin-user "$BYOC_LOGS_POSTGRES_USER" \
  --admin-password "$BYOC_LOGS_POSTGRES_PASSWORD" \
  --sku-name "$BYOC_LOGS_POSTGRES_NODE_SIZE" \
  --tier GeneralPurpose --public-access "$cluster_egress_ip" \
  --storage-size 128 --tags "Environment=Development" \
  --database-name "$BYOC_LOGS_DB_NAME"
