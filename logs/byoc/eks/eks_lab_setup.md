Provision the BYOC Logs EKS Cluster
Variables
There are many variables to keep track of and some have to be unique within AWS.  Using environment variables is recommended for simplicity and correctness.

The environment variables we will use are:



export RESOURCE_NAME=cloudprem-$(hostname)
export CLUSTER=$RESOURCE_NAME
export DB_SUBNET_GROUP=$RESOURCE_NAME
export DB_IDENTIFIER=$RESOURCE_NAME
export BUCKET=$RESOURCE_NAME
export POLICY_NAME=$RESOURCE_NAME
export ROLE_NAME=$RESOURCE_NAME
# change for another region
export REGION=us-west-1
export IAM_SERVICE_ACCOUNT=$RESOURCE_NAME
export NAMESPACE=default
# change if not using the ese sandbox
export PROFILE="--profile account-admin-770341584863" 
export SITE=datadoghq.com # us1
export BYOC_METASTORE_URI=byoc-logs-metastore-uri
export STORAGE_TYPE=gp3
export AWS_LB_ControllerIAMPolicy=AWSLoadBalancerControllerIAMPolicy-$RESOURCE_NAME
export AWS_LB_Controller_Role=aws-lb-controller-role-$RESOURCE_NAME
export WORKLOAD_CLUSTER=workload-cluster-$(date +%s)
To use these we will source them.  Create a file <path>/.env then run:



source <path>/.env
We’ll use a larger instance type for BYOC Logs and OP:



# you will likely create two clusters here
# to switch between the two either:
# 1) kubectl config get-contexts
#    kubectl config use-context <context>
# here that is $CLUSTER or $WORKLOAD_CLUSTER
# 2) aws eks update-kubeconfig --name $CLUSTER --region $REGION $PROFILE
# create cluster
eksctl create cluster --name $CLUSTER --region $REGION --node-type t3.2xlarge \
  --nodes 4 $PROFILE
# create the namespace where you will install and set the context to it
kubectl create ns $NAMESPACE
kubectl config set-context --current --namespace=$NAMESPACE
# oidc provider
eksctl utils associate-iam-oidc-provider --region $REGION \
  --cluster $CLUSTER --approve $PROFILE
# required to use persistent volumes
eksctl create addon --name eks-pod-identity-agent --cluster $CLUSTER \
  --region $REGION $PROFILE
eksctl create addon --name aws-ebs-csi-driver --cluster $CLUSTER \
  --region $REGION $PROFILE
# get profile and migrate add-on
export AWS_PROFILE=$(echo "${PROFILE#* }")
eksctl utils migrate-to-pod-identity --cluster $CLUSTER \
  --region $REGION --approve
We can also create another cluster as a log source (e.g. K8s, applications, etc.).

You may also create these clusters from the AWS Console UI.

Why two clusters?
This represents a more real world scenario where you’d run BYOC Logs in a dedicated cluster instead of next to your workloads.

Can I do this in one cluster instead?
Sure, that is no problem, you will install the agent (and log-generation) on the same cluster as BYOC and OP.

Create an RDS Instance


#get vpc id
VPC_ID=$(aws eks describe-cluster --name $CLUSTER --region $REGION --query \
  "cluster.resourcesVpcConfig.vpcId" --output text $PROFILE)
#get subnets
PUBLIC_SUBNETS=$(aws ec2 describe-subnets --region $REGION  --filters \
  "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[?MapPublicIpOnLaunch==\`true\`].{SubnetId:SubnetId}" \
  --output text $PROFILE)
# create db subnet group
aws rds create-db-subnet-group \
  --db-subnet-group-name $DB_SUBNET_GROUP \
  --db-subnet-group-description "cloudprem subnet group" \
  --region $REGION --subnet-ids $PUBLIC_SUBNETS $PROFILE
# get cluster security group id
CLUSTER_SEC_GROUP=$(aws eks describe-cluster --name $CLUSTER \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
  --region $REGION $PROFILE --output text)
# create db
aws rds create-db-instance --db-instance-identifier $DB_IDENTIFIER \
  --db-instance-class db.t3.micro --engine postgres \
  --master-username cloudprem --master-user-password 'FixMeCloudPrem' \
  --allocated-storage 20 --storage-type $STORAGE_TYPE \
  --db-subnet-group-name $DB_SUBNET_GROUP \
  --vpc-security-group-ids $CLUSTER_SEC_GROUP --db-name cloudprem \
  --backup-retention-period 0 --no-multi-az  --region $REGION $PROFILE
Wait for your RDS instance to become available, check it via: 



# is db ready
ret_val=1
while [ "$ret_val" -ne "0" ];
do
  aws rds describe-db-instances \
    --db-instance-identifier $DB_IDENTIFIER \
    --region $REGION \
    --query 'DBInstances[0].{Status:DBInstanceStatus}' \
    $PROFILE | grep -i available;
  ret_val=$?
  sleep 5
done;
 when it is ready you will get the result: { “Status”: “available” } and the script will exit. 

Create an S3 bucket


# create an s3 bucket - currently it is required to be in the same region as the cluster
aws s3api create-bucket --bucket $BUCKET --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION $PROFILE
Create an IAM Policy Manifest
This will create a policy in iam-policy-2.json



cat <<EOF > iam-policy-2.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudPremS3ObjectPermissions",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListMultipartUploadParts",
                "s3:AbortMultipartUpload"
            ],
            "Resource": [
                "arn:aws:s3:::$BUCKET/*"
            ]
        },
        {
            "Sid": "CloudPremS3BucketPermissions",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": [
                "arn:aws:s3:::$BUCKET"
            ]
        }
    ]
}
EOF
Create the policy:



# create iam policy
aws iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://iam-policy-2.json --region $REGION $PROFILE
Create an IAM Role


# get the policy arn for the role creation
POLICY_ARN=$(aws iam list-policies --query \
  "Policies[?PolicyName=='${POLICY_NAME}'].Arn" \
  --output text $PROFILE)
# create iam role
eksctl create iamserviceaccount --name $IAM_SERVICE_ACCOUNT \
  --cluster $CLUSTER --role-name $ROLE_NAME --region $REGION \
  --attach-policy-arn $POLICY_ARN \
  --namespace $NAMESPACE --approve $PROFILE
Install AWS Load Balancer Controller
Follow Install AWS Load Balancer Controller with Helm - Amazon EKS  // Installation Guide - AWS Load Balancer Controller – the latter can be a bit confusing there’s multiple instructions inside, so suggest following the AWS version.

Use the cluster $CLUSTER for the following operations.

 



curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.4/docs/install/iam_policy.json
 



aws iam create-policy \
  --policy-name $AWS_LB_ControllerIAMPolicy \
  --policy-document file://iam-policy.json --region $REGION $PROFILE
# get the policy arn for the role creation
LB_POLICY_ARN=$(aws iam list-policies --query \
  "Policies[?PolicyName=='${AWS_LB_ControllerIAMPolicy}'].Arn" \
  --output text $PROFILE)
 



eksctl create iamserviceaccount \
--cluster=$CLUSTER \
--namespace=kube-system \
--name=$AWS_LB_Controller_Role \
--attach-policy-arn=$LB_POLICY_ARN \
--region $REGION \
--approve
helm repo add eks https://aws.github.io/eks-charts

wget https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml

kubectl apply -f crds.yaml

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=$CLUSTER --set serviceAccount.create=false --set serviceAccount.name=$AWS_LB_Controller_Role --set vpcId=$VPC_ID --set region=$REGION

kubectl apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.3/cert-manager.yaml

Tag your subnets so the controller can auto-discover them:



aws ec2 create-tags \
  --resources $(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=${VPC_ID}" \
  --query 'Subnets[*].SubnetId' --region $REGION \
    $PROFILE --output text) \
  --tags Key=kubernetes.io/cluster/$CLUSTER,Value=shared \
  --region $REGION $PROFILE
kubernetes.io/role/elb: 1 # for public subnets - tagged already

kubernetes.io/role/internal-elb: 1 # for private subnets - tagged already

Install the BYOC Logs Software
Use the cluster $CLUSTER for the following operations.



# If you switched clusters get the kubeconfig or change context
aws eks update-kubeconfig --name $CLUSTER --region $REGION $PROFILE
kubectl create secret generic datadog-secret --from-literal api-key="<DD_API_KEY>"

Get database connection string:



# get db information for byoc values file
CP_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_IDENTIFIER \
  --query "DBInstances[0].Endpoint.Address" \
  --region $REGION $PROFILE \
  --output text 2>/dev/null) \
&& \
CP_PORT=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_IDENTIFIER \
  --query "DBInstances[0].Endpoint.Port" \
  --region $REGION $PROFILE \
  --output text 2>/dev/null) \
&& \
CP_DATABASE=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_IDENTIFIER \
  --query "DBInstances[0].DBName" \
  --region $REGION $PROFILE \
  --output text 2>/dev/null) \
&& \
QW_METASTORE_URI=$(echo "postgres://cloudprem:FixMeCloudPrem@$CP_ENDPOINT:$CP_PORT/$CP_DATABASE")
This will store something similar to:



postgres://cloudprem:FixMeCloudPrem@cloudprem-postgres.c72c8u0swbl1.us-west-2.rds.amazonaws.com:5432/cloudprem
in the variable QW_METASTORE_URI  To see the values echo $QW_METASTORE_URI



# create the secret for the connection string
kubectl create secret generic $BYOC_METASTORE_URI \
  --from-literal QW_METASTORE_URI=$QW_METASTORE_URI
In preparation, we will add the chart, update and configure our values file.  We will use envsubst so we can use our environment variables.



# get chart
helm repo add datadog https://helm.datadoghq.com
# update
helm repo update
# install the gp3 storage class
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    # Optional: set as default storage class
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
# get the account id
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text $PROFILE)
# documented at https://github.com/DataDog/helm-charts/blob/main/charts/cloudprem/values.yaml
cat << EOF > datadog-values.yaml
aws:
  accountId: "${ACCOUNT_ID}"
environment:
  - name: AWS_REGION
    value: "${REGION}"
datadog:
   site: ${SITE}
   apiKeyExistingSecret: datadog-secret
serviceAccount:
  create: false
  name: ${IAM_SERVICE_ACCOUNT}
  eksRoleName: ${ROLE_NAME}
  extraAnnotations: {}
config:
  default_index_root_uri: s3://${BUCKET}/indexes
metastore:
  extraEnvFrom:
    - secretRef:
        name: byoc-logs-metastore-uri
searcher:
  replicaCount: 2
  podSize: medium
  # uncomment if you want to use a pv with searchers
#  persistentVolume:
#    enabled: true
#    annotations: {}
#    storage: "1Gi"
#    storageClass: "gp3"
indexer:
  persistentVolume:
    enabled: true
    annotations: {}
    storage: "1Gi"
    storageClass: "gp3"
EOF
NOTES: 

We sized the searcher based on the available resources.

 

Install BYOC



# set release name for flexibility
RELEASE_SUFFIX="${RESOURCE_NAME%%-*}"
envsubst < datadog-values.yaml | helm upgrade \
  --install datadog-$RELEASE_SUFFIX datadog/cloudprem -f -
In a production setting you’d want to enabled HPA, size your pods appropriately, etc - we are just taking all the default values from the helm chart

You should see the following:



# k get all
NAME                                                   READY   STATUS    RESTARTS   AGE
pod/datadog-$RELEASE_SUFFIX-control-plane-68ccbcd8f9-59n7b   1/1     Running   0          63m
pod/datadog-$RELEASE_SUFFIX-indexer-0                        1/1     Running   0          52m
pod/datadog-$RELEASE_SUFFIX-indexer-1                        1/1     Running   0          52m
pod/datadog-$RELEASE_SUFFIX-janitor-cd9489869-9ns8t          1/1     Running   0          63m
pod/datadog-$RELEASE_SUFFIX-metastore-5c6fd5c7d5-9lldd       1/1     Running   0          63m
pod/datadog-$RELEASE_SUFFIX-metastore-5c6fd5c7d5-kkknw       1/1     Running   0          63m
pod/datadog-$RELEASE_SUFFIX-searcher-0                       1/1     Running   0          63m
pod/datadog-$RELEASE_SUFFIX-searcher-1                       1/1     Running   0          27m
NAME                                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                               AGE
service/datadog-$RELEASE_SUFFIX-control-plane   ClusterIP   10.100.33.205    <none>        7280/TCP,7281/TCP                     63m
service/datadog-$RELEASE_SUFFIXm-headless        ClusterIP   None             <none>        7280/TCP,7281/TCP,7282/UDP,7283/TCP   63m
service/datadog-$RELEASE_SUFFIX-indexer         ClusterIP   10.100.248.160   <none>        7280/TCP,7281/TCP                     63m
service/datadog-$RELEASE_SUFFIX-janitor         ClusterIP   10.100.173.4     <none>        7280/TCP,7281/TCP                     63m
service/datadog-$RELEASE_SUFFIX-metastore       ClusterIP   10.100.42.16     <none>        7280/TCP,7281/TCP                     63m
service/datadog-$RELEASE_SUFFIX-searcher        ClusterIP   10.100.42.166    <none>        7280/TCP,7281/TCP,7283/TCP            63m
service/kubernetes                        ClusterIP   10.100.0.1       <none>        443/TCP                               83d
NAME                                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/datadog-$RELEASE_SUFFIX-control-plane   1/1     1            1           63m
deployment.apps/datadog-$RELEASE_SUFFIX-janitor         1/1     1            1           63m
deployment.apps/datadog-$RELEASE_SUFFIX-metastore       2/2     2            2           63m
NAME                                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/datadog-$RELEASE_SUFFIX-control-plane-68ccbcd8f9   1         1         1       63m
replicaset.apps/datadog-$RELEASE_SUFFIX-janitor-cd9489869          1         1         1       63m
replicaset.apps/datadog-$RELEASE_SUFFIX-metastore-5c6fd5c7d5       2         2         2       63m
NAME                                          READY   AGE
statefulset.apps/datadog-$RELEASE_SUFFIX-indexer    2/2     63m
statefulset.apps/datadog-$RELEASE_SUFFIX-searcher   2/2     63m
In the DD UI https://app.datadoghq.com/cloudprem you should now see a new cluster listed and active


Observability Pipelines
Create a smaller cluster to simulate workload traffic sent to our BYOC Logs cluster:



# get private subnets
PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=$VPC_ID \
  --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' \
  --region $REGION --output text $PROFILE)
# format variables for argument
PRIVATE_SUBNETS=$(sed 's/ /,/g' <<< $PRIVATE_SUBNETS)
PUBLIC_SUBNETS=$(sed 's/ /,/g' <<< $PUBLIC_SUBNETS)
# create workload cluster in same vpc to make sec rules easier
eksctl create cluster --name $WORKLOAD_CLUSTER \
  --node-type t3.medium --nodes 3 \
  --vpc-private-subnets $PRIVATE_SUBNETS \
  --vpc-public-subnets $PUBLIC_SUBNETS --region $REGION $PROFILE
 

Allow Loadbalancer traffic between clusters
We suggest using a common security group between each of the EKS clusters and the OPW Load Balancer, this simplifies the setup and allows you to set a Security Group Rule that allows all traffic from the Security Group itself. If you do not follow this recommendation then please make sure that TCP port 8282 traffic is allowed from your cp-workload load balancer created by the OP helm chart in the $CLUSTER cluster. In the next section you specify the SG in the OP helm chart ingress (service.beta.kubernetes.io/aws-load-balancer-security-groups: <YOUR-SHARED-SG-ID>) this can be a shared SG with your $WORKLOAD_CLUSTER EKS cluster (or at least allow traffic from it).



# get $WORKLOAD_CLUSTER cluster security group id
WORKLOAD_CLUSTER_SEC_GROUP=$(aws eks describe-cluster --name $WORKLOAD_CLUSTER \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
  --region $REGION $PROFILE --output text)
# create shared sg
OP_LB_SHARED_SEC_GROUP=$(aws ec2 create-security-group \
  --group-name "workload to OP LB" \
  --description "Allow OP traffic from workload cluster" \
  --vpc-id $VPC_ID --region $REGION $PROFILE)
# get group
OP_LB_SHARED_SEC_GROUP=$(echo $OP_LB_SHARED_SEC_GROUP | jq -r '.GroupId')
# add inbound rule
aws ec2 authorize-security-group-ingress \
  --group-id $OP_LB_SHARED_SEC_GROUP \
  --protocol tcp \
  --port 8282 \
  --source-group $WORKLOAD_CLUSTER_SEC_GROUP \
  --region $REGION $PROFILE
Use the cluster $WORKLOAD_CLUSTER for the following operations.

Navigate to https://app.datadoghq.com/observability-pipelines and create a new pipeline with the sensitive data template

Choose “Datadog Agent” as your source

Choose “Datadog BYOC Logs” as your destination

Remove all the processors for now (hover and click delete) except the Edit Fields processor - we will revisit the SDS processor in a later step

Update the Edit Fields Processor:

Change “Fields to add” from field:added to from_op_to_BYOC Logs:true

We do this to easily identify that logs have gone through OP

Click “Next: Install”

Choose “Kubernetes” as your install platform

For the Datadog Agent “Listener address” input 0.0.0.0:8282 (using env vars)

This is the interface (all interfaces) and port for OPW to listen for traffic on

Note: this is only for filling out the in-app install command, it isn’t stored by remote config that gets sent to OPWs. We won’t actually be using the in-app install command, but this gives a sense of how customers might approach this page.

For the “CloudPrem endpoint URL” input the k8s DNS for the CloudPrem indexer service

http://<RELEASE_NAME>-indexer.<NAMESPACE_NAME>.svc.cluster.local:7280

To get the release name and namespace:



# get <RELEASE_NAME>
BYOC_INDEXER_SVC=$(helm ls | grep cloudprem)
BYOC_INDEXER_SVC=$(echo $BYOC_INDEXER_SVC | awk '{print $1}')
# get <NAMESPACE_NAME>
echo $NAMESPACE
Note: this is only for filling out the in-app install command, it isn’t stored by remote config that gets sent to OPWs. We won’t actually be using the in-app install command, but this gives a sense of how customers might approach this page.

Select an API Key

Note: this is only for filling out the in-app install command, it isn’t stored by remote config that gets sent to OPWs. We won’t actually be using the in-app install command, but this gives a sense of how customers might approach this page.

Instead of downloading the values.yaml from the UI - we’ll create our own as we’ll need to define some additional configuration, save it in your local working directory:



## For the full list of configuration options: https://github.com/DataDog/helm-charts/blob/main/charts/observability-pipelines-worker/values.yaml
env:
  - name: DD_OP_SOURCE_DATADOG_AGENT_ADDRESS
    value: "0.0.0.0:8282"
  - name: DD_OP_DESTINATION_CLOUDPREM_ENDPOINT_URL
    value: "http://datadog-<BYOC_INDEXER_SVC>-indexer.<NAMESPACE>.svc.cluster.local:7280"
datadog:
  pipelineId: "<YOUR-PIPELINE-ID>"
  apiKeyExistingSecret: datadog-secret
autoscaling:
  enabled: true
  minReplicas: 2
  targetCPUUtilizationPercentage: 80
podDisruptionBudget:
  enabled: true
  minAvailable: 1
resources:
  requests:
    cpu: 1000m
    memory: 512Mi
service:
  enabled: true
  type: "LoadBalancer"
  annotations:
    # https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/service/annotations/
    service.beta.kubernetes.io/aws-load-balancer-type: internal
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-security-groups: <YOUR-SHARED-SG-ID>
    service.beta.kubernetes.io/aws-load-balancer-manage-backend-security-group-rules: "true"
  ports:
    - name: dd-source-address-port
      port: 8282
      targetPort: 8282
      protocol: TCP
Replace <BYOC_INDEXER_SVC> and <NAMESPACE> with the values from above $BYOC_INDEXER_SVC and $NAMESPACE

Replace <YOUR-PIPELINE-ID> with your Pipeline ID found in the DD URL or in-app install command

Replace <YOUR-SHARED-SG-ID> with the security group shared between your EKS clusters that will allow traffic between the two - (e.g. echo $OP_LB_SHARED_SEC_GROUP)

Back in your terminal make sure you are in the $CLUSTER cluster: aws eks update-kubeconfig --name $CLUSTER --region $REGION $PROFILE # or switch context

Install OP



# create and switch namespace for op
kubectl create ns op
kubectl config set-context --current --namespace=op
# create secret
kubectl create secret generic datadog-secret --from-literal api-key="<API_KEY>"
# install op
helm upgrade --install opw -f values.yaml datadog/observability-pipelines-worker
You should see similar to the following output:



Release "opw" does not exist. Installing it now.
NAME: opw
LAST DEPLOYED: Mon Nov 10 16:43:53 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
Back in the UI you should see your worker has been detected after the pods start up:


Click “Deploy”

The UI will update to show a table with your workers in it

The status column will have a spinner widget in it until the OPWs have taken the config from the remote-config backend

Once complete you’ll see green check marks:


Next click “View Pipeline” to return to the pipeline overview view

Run k get svc and find the opw entry:



opw-observability-pipelines-worker            LoadBalancer   10.100.240.131   k8s-default-opwobser-c7f467599e-35fa6ac7d6137f2d.elb.us-west-2.amazonaws.com   8282:32136/TCP,8686:31755/TCP         18m
We’ll use the k8s-default-opwobser-*.amazonaws.com value in our agent configuration next

Sending logs to OP via the Datadog Agent
Use the cluster $WORKLOAD_CLUSTER for the following operations.

aws eks update-kubeconfig --name $WORKLOAD_CLUSTER --region $REGION $PROFILE # or switch context

kubectl create secret generic datadog-secret --from-literal api-key="<YOUR-API-KEY>"

Save the following file as agent-values.yaml:



# https://github.com/DataDog/helm-charts/blob/main/charts/datadog/values.yaml
datadog:
  apiKeyExistingSecret: datadog-secret
  env:
    - name: DD_OBSERVABILITY_PIPELINES_WORKER_LOGS_ENABLED
      value: true
    - name: DD_OBSERVABILITY_PIPELINES_WORKER_LOGS_URL
      value: "http://<OPW-LOAD-BALANCER-URL>:8282"
  logs:
    enabled: true
    containerCollectAll: true
    autoMultiLineDetection: true
Replace <OPW-LOAD-BALANCER-URL> with your values

<OPW-LOAD-BALANCER-URL> comes from k get svc we ran in the last section, it should look something like: k8s-default-opwobser-c7f467599e-35fa6ac7d6137f2d.elb.us-west-2.amazonaws.com

Install the Datadog agent:



helm upgrade --install datadog-agent datadog/datadog -f agent-values.yaml
Shortly after the agent starts you should see logs in your CloudPrem index in the Log explorer:


Generate logs with a micro-services stack
Use the cluster cp-workload for the following operations.

aws eks update-kubeconfig --name $WORKLOAD_CLUSTER --region $REGION $PROFILE # or switch context

git clone --depth 1 --branch v0 https://github.com/GoogleCloudPlatform/microservices-demo.git

kubectl apply -f ./microservices-demo/release/kubernetes-manifests.yaml

Now you should be able to see your new micro-services stack: k get po:

 



NAME                                           READY   STATUS    RESTARTS   AGE
adservice-dbd9db68f-8h9bv                      1/1     Running   0          13m
cartservice-7d446cd6cd-hf7ht                   1/1     Running   0          13m
checkoutservice-b45957b77-9b7vj                1/1     Running   0          13m
currencyservice-768c464f5-7ghlk                1/1     Running   0          13m
emailservice-5756ddcbb5-prhwx                  1/1     Running   0          13m
frontend-6d47d98676-nzmdt                      1/1     Running   0          13m
loadgenerator-645dcc4d68-4nljd                 1/1     Running   0          13m
paymentservice-69c9f447bf-vnm85                1/1     Running   0          13m
productcatalogservice-66db9f456f-brdqd         1/1     Running   0          13m
recommendationservice-5767cf4d97-gnk9m         1/1     Running   0          13m
redis-cart-c8ff86559-pg8n2                     1/1     Running   0          13m
shippingservice-7c44749569-ddz45               1/1     Running   0          13m
Returning to the Log Explorer for your CloudPrem index you should now see logs coming from these services generating significantly more volume:


Verify logs are flowing through OP
Back in the OP UI (on your pipeline you created in earlier steps) we can verify data is flowing through OP now a few ways:

Via our source and destination overviews:


By clicking the gear icon on our source or destination and click “View Details”


Initiating a Live Capture: Live Capture and seeing the logs flowing through OP

Use Observability Pipelines to redact sensitive data
Before completing the following steps, since we will do it in one swoop, first query the logs explorer for: index:cloudprem-kelnerhax-eks service:paymentservice PaymentService#Charge- replacing cloudprem-kelnerhax-eks with your own index. Open one of these logs and you’ll see fake credit card data, we’ll be removing this with OP.


Navigate to https://app.datadoghq.com/observability-pipelines and select your pipeline you created in the earlier steps

Add the Sensitive Data Scanner Processor by clicking on “Add” at the top of the processor group and clicking on the “Redact Sensitive Data” option

For the filter use service:paymentservice so we don’t scan all logs (targeting specific subsets of logs via filters limits the processing overhead [cpu/mem] that OP will use)

Click on the “ADD Scanning Rule” button

Check “Payment Cards and Banking”

For “Replacement Text” input [redacted_by_op_sds]

Under “Add Tag(s)” click “Add field” and input sensitive_data:true

It should look like the following:


Then Click “Add Rules”

You should now see a bunch of Credit Card and Banking scanning rules in the sidepanel

Close the sidepanel

Deploy your changes

After the deployment finishes and we return to our earlier query of index:cloudprem-kelnerhax-eks service:paymentservice PaymentService#Charge and inspect a log, we can see our credit card has been redacted by SDS within OP!


O11y for BYOC cluster (Datadog Agent)
Use the cluster $CLUSTER for the following operations.

aws eks update-kubeconfig --name $CLUSTER --region $REGION $PROFILE # or switch context

Create a new file locally named cp-dd-agent-values.yaml

Input the following into the file:



# get cluster name
echo $CLUSTER
# https://github.com/DataDog/helm-charts/blob/main/charts/datadog/values.yaml
datadog:
  apiKeyExistingSecret: datadog-secret
  clusterName: <CLUSTER_NAME>
  dogstatsd:
    useHostPort: true
Dogstatsd is enabled by default and this is how BYOC Logs reports its own internal metrics: Monitor BYOC Logs - we need to set useHostPort: true because this is the setting the BYOC Logs helm chart relies on by default

Deploy: helm upgrade --install datadog-agent datadog/datadog -f cp-dd-agent-values.yaml

Shortly thereafter you can see BYOC Logs metrics flowing in: https://app.datadoghq.com/metric/summary?filter=cloudprem

And the OOTB dashboard will be added to your account: https://app.datadoghq.com/dash/integration/32086/datadog-cloudprem

It may take up to 15 minutes to show up


You can also look in the kubernetes explorer and find your cluster and its associated resources:


Deleting Resources for the Clusters
We used environment variables to simplify and ensure correctness.  We also need to clean up as some of these resources must be unique.  We should have addressed conflicts with the cluster having the time since the epoch appended, but still let’s try to keep the ese sandbox clean.  

NOTE: see if the env vars are still in your environment.  e.g. echo $CLUSTER  If not, then you need to set them again.  You need to export the variables again setting RESOURCE_NAME to the the byoc/op cluster name and WORKLOAD_CLUSTER to the workload cluster name.



# delete the workload cluster
eksctl delete cluster --name $WORKLOAD_CLUSTER --region $REGION $PROFILE
# delete db - no snapshot
aws rds delete-db-instance \
  --db-instance-identifier $DB_IDENTIFIER \
  --region $REGION $PROFILE --skip-final-snapshot
# delete db subnet group - after db done deleting - see db status command above
aws rds delete-db-subnet-group \
  --db-subnet-group-name $DB_SUBNET_GROUP \
  --region $REGION $PROFILE
# delete bucket
aws s3 rb s3://$BUCKET --region $REGION $PROFILE --force
# delete cluster
eksctl delete cluster --name $CLUSTER --region $REGION $PROFILE 
# delete policy - if created
aws iam delete-policy \
 --policy-arn $POLICY_ARN --region $REGION $PROFILE
