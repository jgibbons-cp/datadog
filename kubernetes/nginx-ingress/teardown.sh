#!/bin/bash

# make sure you can reach cluster
if ! kubectl get pods &> /dev/null; then
    echo "No cluster configured... exiting...\n"
    exit 1
fi

# delete knote app
pushd ../../kubernetes/nodejs_tracing/dockerfile_configuration/
kubectl delete -f knote.yaml
kubectl delete -f knote_clusterip_svc.yaml
kubectl delete -f mongo.yaml
popd

# delete nginx ingress controller
NAMESPACE=ingress-nginx

# uninstall ingress controller
helm uninstall ingress-nginx -n $NAMESPACE

# delete ingress
kubectl delete -f application_ingress.yaml

# delete secret
kubectl delete secret dd-rum-tokens

# deploy app java
pushd ../../app-java/kubernetes/
kubectl delete -f app-java.yaml
kubectl delete -f app_java_clusterip_svc.yaml 
kubectl delete -f mysql_ja.yaml
popd
