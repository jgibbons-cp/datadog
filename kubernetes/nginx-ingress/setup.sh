#!/bin/bash

SUCCESS=0
MAX_TRIES=5
counter=0
INCREMENT=1

cmd() {
    ls -l "/tmp/test/my dir" &>/dev/null
}

# make sure you can reach cluster
if ! kubectl get pods &> /dev/null; then
    echo "No cluster configured... exiting...\n"
    exit 1
fi

# deploy knote app
pushd ../../kubernetes/nodejs_tracing/dockerfile_configuration/
sed -i .bak 's/<repo>\/<image>:<tag>/jenksgibbons\/knote:no_tracer/' knote.yaml 
kubectl create -f knote.yaml
kubectl create -f knote_clusterip_svc.yaml
kubectl create -f mongo.yaml
popd

# deploy nginx ingress controller
NAMESPACE=ingress-nginx

# get public ip
public_ip=$(curl api.ipify.org)

# get / update charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# install ingress controller
helm install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace $NAMESPACE \
--set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
--set controller.service.loadBalancerSourceRanges="{$public_ip/32}"

# get az username for public dns for lb
principal_username=$(az ad signed-in-user show --query "userPrincipalName" | tr -d '"' | tr -d "." | sed 's/@.*//')
kubectl annotate svc -n ingress-nginx ingress-nginx-controller service.beta.kubernetes.io/azure-dns-label-name=$principal_username

# get public dns
azure_region=$(kubectl get nodes --show-labels --no-headers | grep -v aks-default | sed -e 's/.*region\(.*\),.*/\1/' | tr -d '=' | tr -d '\n')
rest_fqdn=".cloudapp.azure.com"
fqdn=$principal_username.$azure_region$rest_fqdn

# update ingress with dns
sed -i .bak "s/<FQDN>/$fqdn/" application_ingress.yaml

# install ingress - 4 retries
cmd
while [ "$?" != $SUCCESS ] && [ "$counter" -lt $MAX_TRIES ]; do
  #echo fail
  counter=$((counter + $INCREMENT))
  #echo $counter
  sleep 2
  cmd
done

echo $?
echo 
echo exit
exit 0

# create secret so app will run, don't need rum here so just keep with fake data
kubectl create secret generic dd-rum-tokens --from-literal CLIENT_TOKEN=TOKEN --from-literal APPLICATION_ID=APPID

# deploy app java
pushd ../../app-java/kubernetes/
kubectl create -f app-java.yaml
kubectl create -f app_java_clusterip_svc.yaml 
kubectl create -f mysql_ja.yaml
popd

# hit the node app
echo "\nThe node app is now available at http://$fqdn\n"

# hit the java app
echo "The java app is now available at http://$fqdn/app-java-0.0.1-SNAPSHOT/"