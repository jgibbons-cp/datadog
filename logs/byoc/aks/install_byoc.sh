#!/bin/bash

source ./.env

helm repo add datadog https://helm.datadoghq.com
helm repo update || true

NAMESPACE=byoclogs

kubectl config set-context --current --namespace=$NAMESPACE

kubectl create secret generic datadog-secret \
  --from-literal api-key=$API_KEY

connection_string="postgres://$BYOC_LOGS_POSTGRES_USER:$BYOC_LOGS_POSTGRES_PASSWORD@$BYOC_LOGS_POSTGRES_NAME.postgres.database.azure.com:5432/$BYOC_LOGS_DB_NAME"

kubectl create secret generic byoc-logs-metastore-uri \
  --from-literal QW_METASTORE_URI="$connection_string"

helm upgrade --install byoclogs datadog/cloudprem -f datadog-values-modified.yaml

# install operator
helm repo add datadog https://helm.datadoghq.com
helm install my-datadog-operator datadog/datadog-operator

kubectl get po  | grep operator | grep 1/1

while [ "$?" -ne 0 ]; do
    echo "Waiting for running operator..."
    sleep 1
    kubectl get po  | grep operator | grep 1/1
done

kubectl apply -f agent-values.yaml