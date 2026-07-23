#!/usr/bin/env bash
#
# eks_lab_setup.sh
#
# Automates the scriptable steps from eks_lab_setup.md (BYOC Logs + Observability
# Pipelines EKS lab). Steps that require the Datadog UI (creating an OP pipeline,
# selecting an API key, grabbing the pipeline ID, etc.) are called out explicitly
# and paused on with a prompt rather than automated.
#
# Usage:
#   ./eks_lab_setup.sh <command> [args...]
#
# Run './eks_lab_setup.sh help' for the list of commands, or './eks_lab_setup.sh all'
# to run the full BYOC-cluster bring-up in order (stops before the OP UI steps).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"

log()  { printf '\033[1;34m[eks-lab]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[eks-lab]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[eks-lab]\033[0m %s\n' "$*" >&2; exit 1; }

pause_for_manual_step() {
  warn "MANUAL STEP REQUIRED: $*"
  read -r -p "Press Enter once you've completed this in the Datadog UI to continue... "
}

require_env() {
  local missing=0
  for var in "$@"; do
    if [ -z "${!var:-}" ]; then
      warn "Required variable \$$var is not set"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || die "Missing required environment variables. Did you run 'init-env' and source $ENV_FILE?"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command '$1' not found in PATH"
}

# ---------------------------------------------------------------------------
# init-env: write out the default .env with the variables from the doc
# ---------------------------------------------------------------------------
cmd_init_env() {
  if [ -f "$ENV_FILE" ]; then
    #replace="n"
    read -p "$ENV_FILE already exists, do you want to replace it? " replace
    
    case "$replace" in
      y | Y)
        echo "Overwriting $ENV_FILE..."
        rm $ENV_FILE
        ;;
      n | N)
        echo "Using current $ENV_FILE..."
        ;;
      *)
        echo "Invalid selection... exiting..."
        exit 1
        ;;
    esac
  fi

HOSTNAME=$(hostname)
HOSTNAME=$(awk '{print tolower($0)}' <<< "$HOSTNAME")
RESOURCE_NAME=byoc-$HOSTNAME

  cat > "$ENV_FILE" <<EOF
export RESOURCE_NAME=$RESOURCE_NAME
export CLUSTER=$RESOURCE_NAME
export K8S_VERSION="1.36"
export NODE_TYPE=m5.4xlarge
export DB_SUBNET_GROUP=$RESOURCE_NAME
export DB_IDENTIFIER=$RESOURCE_NAME
export BUCKET=$RESOURCE_NAME
export POLICY_NAME=$RESOURCE_NAME
export ROLE_NAME=$RESOURCE_NAME

# change for another region
export REGION=us-west-1
export IAM_SERVICE_ACCOUNT=$RESOURCE_NAME
export NAMESPACE=byoclogs

# change if not using the ese sandbox
export PROFILE="--profile account-admin-770341584863"
export SITE=datadoghq.com # us1
export BYOC_METASTORE_URI=byoc-logs-metastore-uri
export STORAGE_TYPE=gp3
export AWS_LB_ControllerIAMPolicy=AWSLoadBalancerControllerIAMPolicy-$RESOURCE_NAME
export AWS_LB_Controller_Role=aws-lb-controller-role-$RESOURCE_NAME
export WORKLOAD_CLUSTER=workload-cluster-"${HOSTNAME}"
EOF
  log "Edit it if needed, then run: source $ENV_FILE"
}

# ---------------------------------------------------------------------------
# create-cluster: BYOC/OP cluster + oidc + pod-identity/ebs addons
# ---------------------------------------------------------------------------
cmd_create_cluster() {
  require_env CLUSTER REGION PROFILE NAMESPACE
  need_cmd eksctl; need_cmd kubectl

  aws configure sso

  VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
    --region $REGION $PROFILE --query "Vpcs[0].VpcId" --output text)
  log "Got default VPC ID: $VPC_ID"

  log "Getting default VPC public subnets"
  SUBNET_1=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[0].SubnetId" $PROFILE \
    --region $REGION --output text)
  log "Got first subnet: $SUBNET_1"

  SUBNET_2=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[1].SubnetId" $PROFILE \
    --region $REGION --output text)
  log "Got second subnet: $SUBNET_2"

  log "Creating cluster $CLUSTER in $REGION"
  cp cluster.yaml cluster-modified.yaml
  sed -i '' "s/CLUSTER/${CLUSTER}/" cluster-modified.yaml
  sed -i '' "s/REGION/${REGION}/" cluster-modified.yaml
  sed -i '' "s/K8S_VERSION/${K8S_VERSION}/" cluster-modified.yaml
  sed -i '' "s/NODE_TYPE/${NODE_TYPE}/" cluster-modified.yaml
  sed -i '' "s/SUBNET_1/${SUBNET_1}/" cluster-modified.yaml
  sed -i '' "s/SUBNET_2/${SUBNET_2}/" cluster-modified.yaml
  
  eksctl create cluster -f cluster-modified.yaml $PROFILE

  log "Creating namespace $NAMESPACE and setting current context"
  kubectl create ns "$NAMESPACE"
  kubectl config set-context --current --namespace="$NAMESPACE"

  log "Associating IAM OIDC provider"
  eksctl utils associate-iam-oidc-provider --region "$REGION" \
    --cluster "$CLUSTER" --approve $PROFILE

  log "Installing eks-pod-identity-agent and aws-ebs-csi-driver addons"
  eksctl create addon --name eks-pod-identity-agent --cluster "$CLUSTER" \
    --region "$REGION" $PROFILE
  eksctl create addon --name aws-ebs-csi-driver --cluster "$CLUSTER" \
    --region "$REGION" $PROFILE

  export AWS_PROFILE
  AWS_PROFILE=$(echo "${PROFILE#* }")
  log "Migrating add-ons to pod identity (AWS_PROFILE=$AWS_PROFILE)"
  eksctl utils migrate-to-pod-identity --cluster "$CLUSTER" \
    --region "$REGION" --approve

  # get kubeconfig and export it to the shell
  aws eks update-kubeconfig --region $REGION --name $CLUSTER $PROFILE \
    --kubeconfig $(pwd)/config
  echo "export KUBECONFIG=$(pwd)/config" > /tmp/kubeconfig.tmp
  source /tmp/kubeconfig.tmp

  log "Cluster $CLUSTER ready."
}

# ---------------------------------------------------------------------------
# create-rds: RDS postgres instance for cloudprem metastore
# ---------------------------------------------------------------------------
cmd_create_rds() {

  require_env CLUSTER REGION PROFILE DB_SUBNET_GROUP DB_IDENTIFIER STORAGE_TYPE
  need_cmd aws; need_cmd jq

  aws configure sso

  log "Looking up VPC id for cluster $CLUSTER"
  VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --region "$REGION" --query \
    "cluster.resourcesVpcConfig.vpcId" --output text $PROFILE)
  export VPC_ID
  log "VPC_ID=$VPC_ID"

  log "Looking up public subnets"
  PUBLIC_SUBNETS=$(aws ec2 describe-subnets --region "$REGION" --filters \
    "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[?MapPublicIpOnLaunch==\`true\`].{SubnetId:SubnetId}" \
    --output text $PROFILE)
  export PUBLIC_SUBNETS
  log "PUBLIC_SUBNETS=$PUBLIC_SUBNETS"

  log "Creating DB subnet group $DB_SUBNET_GROUP"
  aws rds create-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --db-subnet-group-description "cloudprem subnet group" \
    --region "$REGION" --subnet-ids $PUBLIC_SUBNETS $PROFILE \
    > /dev/null

  log "Looking up cluster security group"
  CLUSTER_SEC_GROUP=$(aws eks describe-cluster --name "$CLUSTER" \
    --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
    --region "$REGION" $PROFILE --output text)
  export CLUSTER_SEC_GROUP

  log "Creating RDS instance $DB_IDENTIFIER (this can take several minutes)"
  aws rds create-db-instance --db-instance-identifier "$DB_IDENTIFIER" \
    --db-instance-class db.t3.micro --engine postgres \
    --master-username cloudprem --master-user-password 'FixMeCloudPrem' \
    --allocated-storage 20 --storage-type "$STORAGE_TYPE" \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --vpc-security-group-ids "$CLUSTER_SEC_GROUP" --db-name cloudprem \
    --backup-retention-period 0 --no-multi-az --region "$REGION" $PROFILE \
    > /dev/null

  log "Waiting for RDS instance to become available..."
  local ret_val=1
  set +e
  while [ "$ret_val" -ne "0" ]; do
    aws rds describe-db-instances \
      --db-instance-identifier "$DB_IDENTIFIER" \
      --region "$REGION" \
      --query 'DBInstances[0].{Status:DBInstanceStatus}' \
      $PROFILE | grep -i available
    ret_val=$?
    [ "$ret_val" -eq 0 ] || log "Sleeping for 30 seconds"; sleep 30
  done
  set -e

  log "RDS instance $DB_IDENTIFIER is available."
}

# ---------------------------------------------------------------------------
# create-s3: bucket for cloudprem indexes
# ---------------------------------------------------------------------------
cmd_create_s3() {
  require_env BUCKET REGION PROFILE
  need_cmd aws

  log "Creating S3 bucket $BUCKET in $REGION"
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" $PROFILE
}

# ---------------------------------------------------------------------------
# create-iam: policy + iamserviceaccount for cloudprem s3 access
# ---------------------------------------------------------------------------
cmd_create_iam() {
  require_env BUCKET POLICY_NAME REGION PROFILE CLUSTER ROLE_NAME IAM_SERVICE_ACCOUNT NAMESPACE
  need_cmd aws; need_cmd eksctl

  local policy_file="$SCRIPT_DIR/iam-policy-2.json"
  log "Writing IAM policy manifest to $policy_file"
  cat <<EOF > "$policy_file"
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

  log "Creating IAM policy $POLICY_NAME"
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "file://$policy_file" --region "$REGION" $PROFILE

  log "Looking up policy ARN"
  POLICY_ARN=$(aws iam list-policies --query \
    "Policies[?PolicyName=='${POLICY_NAME}'].Arn" \
    --output text $PROFILE)
  export POLICY_ARN
  log "POLICY_ARN=$POLICY_ARN"

  log "Creating iamserviceaccount $IAM_SERVICE_ACCOUNT"
  eksctl create iamserviceaccount --name "$IAM_SERVICE_ACCOUNT" \
    --cluster "$CLUSTER" --role-name "$ROLE_NAME" --region "$REGION" \
    --attach-policy-arn "$POLICY_ARN" \
    --namespace "$NAMESPACE" $PROFILE --approve 
}

# ---------------------------------------------------------------------------
# install-lb-controller: AWS Load Balancer Controller via Helm
# ---------------------------------------------------------------------------
cmd_install_lb_controller() {
  require_env CLUSTER REGION PROFILE AWS_LB_ControllerIAMPolicy AWS_LB_Controller_Role
  need_cmd aws; need_cmd eksctl; need_cmd helm; need_cmd kubectl; need_cmd curl; need_cmd wget

  if [ -z "${VPC_ID:-}" ]; then
    VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --region "$REGION" --query \
      "cluster.resourcesVpcConfig.vpcId" --output text $PROFILE)
    export VPC_ID
  fi
  log "Grabned VPC ID: $VPC_ID"

  local iam_policy_file="$SCRIPT_DIR/iam-policy.json"
  log "Downloading AWS Load Balancer Controller IAM policy"
  curl -o "$iam_policy_file" https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.4/docs/install/iam_policy.json

  log "Creating IAM policy $AWS_LB_ControllerIAMPolicy"
  aws iam create-policy \
    --policy-name "$AWS_LB_ControllerIAMPolicy" \
    --policy-document "file://$iam_policy_file" --region "$REGION" $PROFILE

  LB_POLICY_ARN=$(aws iam list-policies --query \
    "Policies[?PolicyName=='${AWS_LB_ControllerIAMPolicy}'].Arn" \
    --output text $PROFILE)
  export LB_POLICY_ARN
  log "LB_POLICY_ARN=$LB_POLICY_ARN"
  
  log "Creating iamserviceaccount $AWS_LB_Controller_Role"
  # debug 
  #log export CLUSTER=$CLUSTER 
  #log export AWS_LB_Controller_Role=$AWS_LB_Controller_Role 
  #log export LB_POLICY_ARN=$LB_POLICY_ARN 
  #log export REGION=$REGION
  
  eksctl create iamserviceaccount \
    --cluster="$CLUSTER" \
    --namespace=kube-system \
    --name="$AWS_LB_Controller_Role" \
    --attach-policy-arn="$LB_POLICY_ARN" \
    --region "$REGION" $PROFILE \
    --approve

  until kubectl get sa $AWS_LB_Controller_Role -n kube-system &>/dev/null; do
    echo "Waiting for ServiceAccount..."
    sleep 5
  done

  log "Adding eks-charts helm repo"
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update eks

  log "Applying LB controller CRDs"
  wget -O "$SCRIPT_DIR/crds.yaml" https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml
  kubectl apply -f "$SCRIPT_DIR/crds.yaml"

  log "Installing aws-load-balancer-controller"
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system --set clusterName="$CLUSTER" --set serviceAccount.create=false \
    --set serviceAccount.name="$AWS_LB_Controller_Role" --set vpcId="$VPC_ID" --set region="$REGION"

  log "Waiting for aws-load-balancer-controller to be ready..."
  aws_lb_controllers_pod1=$(kubectl -n kube-system get pods -o jsonpath='{range .items[0]}{.metadata.name}{"\n"}{end}' \
    | grep "aws-load-balancer-controller-")
  aws_lb_controllers_pod2=$(kubectl -n kube-system get pods -o jsonpath='{range .items[1]}{.metadata.name}{"\n"}{end}' \
    | grep "aws-load-balancer-controller-")
  
  kubectl wait pod $aws_lb_controllers_pod1 $aws_lb_controllers_pod2 --for=condition=Ready \
    --namespace=kube-system --timeout=300s

  log "Installing cert-manager"
  kubectl apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.3/cert-manager.yaml

  log "Tagging subnets for auto-discovery"
  aws ec2 create-tags \
    --resources $(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[*].SubnetId' --region "$REGION" \
      $PROFILE --output text) \
    --tags Key=kubernetes.io/cluster/"$CLUSTER",Value=shared \
    --region "$REGION" $PROFILE

  warn "Reminder: your public subnets should already be tagged kubernetes.io/role/elb=1"
  warn "and private subnets kubernetes.io/role/internal-elb=1 (per EKS default VPC tagging)."
}

# ---------------------------------------------------------------------------
# install-byoc: install BYOC Logs (cloudprem) helm chart
# ---------------------------------------------------------------------------
cmd_install_byoc() {
  require_env CLUSTER REGION PROFILE DB_IDENTIFIER BYOC_METASTORE_URI RESOURCE_NAME SITE IAM_SERVICE_ACCOUNT ROLE_NAME BUCKET NAMESPACE

  need_cmd aws; need_cmd kubectl; need_cmd helm; need_cmd envsubst

  set +e
  kubectl config set-context --current --namespace=$NAMESPACE

  if [ -z "${DD_API_KEY:-}" ]; then
    read -r -s -p "Enter your Datadog API key (DD_API_KEY): " DD_API_KEY
    echo
  fi
  log "Creating datadog-secret in namespace $NAMESPACE"
  kubectl create secret generic datadog-secret \
    --from-literal api-key="$DD_API_KEY"

  log "Fetching DB connection info for $DB_IDENTIFIER"
  CP_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].Endpoint.Address" \
    --region "$REGION" $PROFILE \
    --output text 2>/dev/null)
  CP_PORT=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].Endpoint.Port" \
    --region "$REGION" $PROFILE \
    --output text 2>/dev/null)
  CP_DATABASE=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].DBName" \
    --region "$REGION" $PROFILE \
    --output text 2>/dev/null)
  QW_METASTORE_URI="postgres://cloudprem:FixMeCloudPrem@$CP_ENDPOINT:$CP_PORT/$CP_DATABASE"
  log "QW_METASTORE_URI=$QW_METASTORE_URI"

  log "Creating $BYOC_METASTORE_URI secret"
  kubectl create secret generic "$BYOC_METASTORE_URI" \
    --from-literal QW_METASTORE_URI="$QW_METASTORE_URI"
  set -e

  log "Adding/updating datadog helm repo"
  helm repo add datadog https://helm.datadoghq.com
  helm repo update datadog

  log "Installing gp3 StorageClass"
  cat << EOF | kubectl apply -f -
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
  
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text $PROFILE)
  export ACCOUNT_ID REGION SITE IAM_SERVICE_ACCOUNT ROLE_NAME BUCKET

  echo $ACCOUNT_ID 
  echo $REGION 
  echo $SITE 
  echo $IAM_SERVICE_ACCOUNT 
  echo $ROLE_NAME 
  echo $BUCKET

  local values_file="$SCRIPT_DIR/datadog-values.yaml"
  log "Writing $values_file"
  cat << EOF > "$values_file"
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
  replicaCount: 1
  podSize: medium
# uncomment if you want to use a pv with searchers
#. persistentVolume:
#    enabled: true
#    annotations: {}
#    storage: "1Gi"
#    storageClass: "gp3"
indexer:
  podSize: medium
  persistentVolume:
    enabled: true
    annotations: {}
    storage: "1Gi"
    storageClass: "gp3"
EOF

  RELEASE_SUFFIX="${RESOURCE_NAME%%-*}"
  export RELEASE_SUFFIX
  log "Installing cloudprem release datadog-$RELEASE_SUFFIX"
  envsubst < "$values_file" | helm upgrade \
    --install "datadog-$RELEASE_SUFFIX" datadog/cloudprem -f - \
    -n $NAMESPACE

  log "Check status with: kubectl get all"
  log "In the DD UI: https://app.${SITE}/cloudprem"
}

# ---------------------------------------------------------------------------
# create-workload-cluster: second smaller cluster for OP + log generation
# ---------------------------------------------------------------------------
cmd_create_workload_cluster() {
  require_env VPC_ID WORKLOAD_CLUSTER REGION PROFILE
  need_cmd aws; need_cmd eksctl

  log "Looking up private/public subnets in VPC $VPC_ID"
  PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filter Name=vpc-id,Values="$VPC_ID" \
    --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' \
    --region "$REGION" --output text $PROFILE)
  PUBLIC_SUBNETS=$(aws ec2 describe-subnets --region "$REGION" --filters \
    "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[?MapPublicIpOnLaunch==\`true\`].{SubnetId:SubnetId}" \
    --output text $PROFILE)
  PRIVATE_SUBNETS=$(sed 's/ /,/g' <<< "$PRIVATE_SUBNETS")
  PUBLIC_SUBNETS=$(sed 's/ /,/g' <<< "$PUBLIC_SUBNETS")
  export PRIVATE_SUBNETS PUBLIC_SUBNETS

  log "Creating workload cluster $WORKLOAD_CLUSTER"
  eksctl create cluster --name "$WORKLOAD_CLUSTER" \
    --node-type t3.medium --nodes 3 \
    --vpc-private-subnets "$PRIVATE_SUBNETS" \
    --vpc-public-subnets "$PUBLIC_SUBNETS" --region "$REGION" $PROFILE
}

# ---------------------------------------------------------------------------
# setup-sg: shared security group allowing workload -> OP LB traffic on 8282
# ---------------------------------------------------------------------------
cmd_setup_sg() {
  require_env WORKLOAD_CLUSTER VPC_ID REGION PROFILE
  need_cmd aws; need_cmd jq

  log "Looking up workload cluster security group"
  WORKLOAD_CLUSTER_SEC_GROUP=$(aws eks describe-cluster --name "$WORKLOAD_CLUSTER" \
    --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
    --region "$REGION" $PROFILE --output text)
  export WORKLOAD_CLUSTER_SEC_GROUP
  log "WORKLOAD_CLUSTER_SEC_GROUP=$WORKLOAD_CLUSTER_SEC_GROUP"

  log "Creating shared security group for OP LB"
  OP_LB_SHARED_SEC_GROUP=$(aws ec2 create-security-group \
    --group-name "workload to OP LB" \
    --description "Allow OP traffic from workload cluster" \
    --vpc-id "$VPC_ID" --region "$REGION" $PROFILE)
  OP_LB_SHARED_SEC_GROUP=$(echo "$OP_LB_SHARED_SEC_GROUP" | jq -r '.GroupId')
  export OP_LB_SHARED_SEC_GROUP
  log "OP_LB_SHARED_SEC_GROUP=$OP_LB_SHARED_SEC_GROUP"

  log "Authorizing ingress on port 8282 from workload cluster SG"
  aws ec2 authorize-security-group-ingress \
    --group-id "$OP_LB_SHARED_SEC_GROUP" \
    --protocol tcp \
    --port 8282 \
    --source-group "$WORKLOAD_CLUSTER_SEC_GROUP" \
    --region "$REGION" $PROFILE

  log "Save this for the OP values.yaml: OP_LB_SHARED_SEC_GROUP=$OP_LB_SHARED_SEC_GROUP"
}

# ---------------------------------------------------------------------------
# create-op-pipeline: manual UI step reminder
# ---------------------------------------------------------------------------
cmd_create_op_pipeline() {
  require_env CLUSTER REGION PROFILE
  need_cmd aws; need_cmd helm

  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" $PROFILE

  BYOC_INDEXER_SVC=$(helm ls | grep cloudprem || true)
  BYOC_INDEXER_SVC=$(echo "$BYOC_INDEXER_SVC" | awk '{print $1}')
  log "BYOC_INDEXER_SVC=$BYOC_INDEXER_SVC"
  log "NAMESPACE=${NAMESPACE:-}"

  pause_for_manual_step "Create the OP pipeline at https://app.${SITE:-datadoghq.com}/observability-pipelines
  - Source: Datadog Agent, Destination: Datadog BYOC Logs
  - Remove all processors except Edit Fields; set field from_op_to_BYOC_Logs:true
  - Install platform: Kubernetes, Listener address: 0.0.0.0:8282
  - CloudPrem endpoint URL: http://${BYOC_INDEXER_SVC}-indexer.${NAMESPACE:-default}.svc.cluster.local:7280
  - Select an API key, note your Pipeline ID (from the URL or in-app install command)"

  read -r -p "Enter your Pipeline ID: " OP_PIPELINE_ID
  export OP_PIPELINE_ID
  log "OP_PIPELINE_ID=$OP_PIPELINE_ID (remember this for install-op)"
}

# ---------------------------------------------------------------------------
# install-op: install the Observability Pipelines Worker on $CLUSTER
# ---------------------------------------------------------------------------
cmd_install_op() {
  require_env CLUSTER REGION PROFILE NAMESPACE
  need_cmd aws; need_cmd kubectl; need_cmd helm; need_cmd envsubst

  if [ -z "${BYOC_INDEXER_SVC:-}" ]; then
    BYOC_INDEXER_SVC=$(helm ls -n "$NAMESPACE" | grep cloudprem || true)
    BYOC_INDEXER_SVC=$(echo "$BYOC_INDEXER_SVC" | awk '{print $1}')
  fi
  [ -n "${OP_PIPELINE_ID:-}" ] || read -r -p "Enter your OP Pipeline ID: " OP_PIPELINE_ID
  [ -n "${OP_LB_SHARED_SEC_GROUP:-}" ] || read -r -p "Enter your shared security group ID: " OP_LB_SHARED_SEC_GROUP
  export BYOC_INDEXER_SVC OP_PIPELINE_ID OP_LB_SHARED_SEC_GROUP NAMESPACE

  local values_file="$SCRIPT_DIR/op-values.yaml"
  log "Writing $values_file"
  cat << 'EOF' > "$values_file"
## For the full list of configuration options: https://github.com/DataDog/helm-charts/blob/main/charts/observability-pipelines-worker/values.yaml
env:
  - name: DD_OP_SOURCE_DATADOG_AGENT_ADDRESS
    value: "0.0.0.0:8282"
  - name: DD_OP_DESTINATION_CLOUDPREM_ENDPOINT_URL
    value: "http://${BYOC_INDEXER_SVC}-indexer.${NAMESPACE}.svc.cluster.local:7280"
datadog:
  pipelineId: "${OP_PIPELINE_ID}"
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
    service.beta.kubernetes.io/aws-load-balancer-security-groups: ${OP_LB_SHARED_SEC_GROUP}
    service.beta.kubernetes.io/aws-load-balancer-manage-backend-security-group-rules: "true"
  ports:
    - name: dd-source-address-port
      port: 8282
      targetPort: 8282
      protocol: TCP
EOF

  log "Rendered values written to ${values_file}.rendered"
  envsubst < "$values_file" > "${values_file}.rendered"

  log "Making sure we're on cluster $CLUSTER"
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" $PROFILE

  log "Creating op namespace and switching context"
  kubectl create ns op 2>/dev/null || warn "namespace op already exists"
  kubectl config set-context --current --namespace=op

  if [ -z "${DD_API_KEY:-}" ]; then
    read -r -s -p "Enter your Datadog API key (DD_API_KEY): " DD_API_KEY
    echo
  fi
  kubectl create secret generic datadog-secret --from-literal api-key="$DD_API_KEY" 2>/dev/null || warn "secret already exists"

  log "Installing observability-pipelines-worker"
  helm upgrade --install opw -f "${values_file}.rendered" datadog/observability-pipelines-worker

  pause_for_manual_step "In the OP UI click 'Deploy' and wait for workers to show green check marks."

  log "Run 'kubectl get svc -n op' to find the opw LoadBalancer hostname for the next step."
}

# ---------------------------------------------------------------------------
# install-agent-workload: install DD agent on workload cluster, forwarding to OP
# ---------------------------------------------------------------------------
cmd_install_agent_workload() {
  require_env WORKLOAD_CLUSTER REGION PROFILE
  need_cmd aws; need_cmd kubectl; need_cmd helm

  aws eks update-kubeconfig --name "$WORKLOAD_CLUSTER" --region "$REGION" $PROFILE

  if [ -z "${DD_API_KEY:-}" ]; then
    read -r -s -p "Enter your Datadog API key (DD_API_KEY): " DD_API_KEY
    echo
  fi
  kubectl create secret generic datadog-secret --from-literal api-key="$DD_API_KEY" 2>/dev/null || warn "secret already exists"

  [ -n "${OPW_LB_URL:-}" ] || read -r -p "Enter the OPW LoadBalancer hostname (from 'kubectl get svc -n op'): " OPW_LB_URL
  export OPW_LB_URL

  local values_file="$SCRIPT_DIR/agent-values.yaml"
  log "Writing $values_file"
  cat << 'EOF' > "$values_file"
# https://github.com/DataDog/helm-charts/blob/main/charts/datadog/values.yaml
datadog:
  apiKeyExistingSecret: datadog-secret
  env:
    - name: DD_OBSERVABILITY_PIPELINES_WORKER_LOGS_ENABLED
      value: true
    - name: DD_OBSERVABILITY_PIPELINES_WORKER_LOGS_URL
      value: "http://${OPW_LB_URL}:8282"
  logs:
    enabled: true
    containerCollectAll: true
    autoMultiLineDetection: true
EOF
  envsubst < "$values_file" > "${values_file}.rendered"

  log "Installing datadog-agent on $WORKLOAD_CLUSTER"
  helm upgrade --install datadog-agent datadog/datadog -f "${values_file}.rendered"
}

# ---------------------------------------------------------------------------
# generate-load: deploy the microservices-demo app on the workload cluster
# ---------------------------------------------------------------------------
cmd_generate_load() {
  require_env WORKLOAD_CLUSTER REGION PROFILE
  need_cmd aws; need_cmd kubectl; need_cmd git

  aws eks update-kubeconfig --name "$WORKLOAD_CLUSTER" --region "$REGION" $PROFILE

  local repo_dir="$SCRIPT_DIR/microservices-demo"
  if [ ! -d "$repo_dir" ]; then
    log "Cloning microservices-demo"
    git clone --depth 1 --branch v0 https://github.com/GoogleCloudPlatform/microservices-demo.git "$repo_dir"
  else
    warn "$repo_dir already exists, skipping clone"
  fi

  log "Applying microservices-demo manifests"
  kubectl apply -f "$repo_dir/release/kubernetes-manifests.yaml"

  log "Run 'kubectl get po' to watch pods come up."
}

# ---------------------------------------------------------------------------
# redact-sensitive-data: manual UI step reminder
# ---------------------------------------------------------------------------
cmd_redact_sensitive_data() {
  pause_for_manual_step "In the Log Explorer, query: index:<your-index> service:paymentservice PaymentService#Charge
  and confirm you see raw fake credit card data. Then on your pipeline
  (https://app.${SITE:-datadoghq.com}/observability-pipelines):
  - Add a 'Redact Sensitive Data' processor
  - Filter: service:paymentservice
  - Add scanning rule: check 'Payment Cards and Banking'
  - Replacement text: [redacted_by_op_sds]
  - Add tag: sensitive_data:true
  - Deploy your changes
  Then re-run the same query to confirm the card data is now redacted."
}

# ---------------------------------------------------------------------------
# install-agent-byoc: DD agent for BYOC cluster's own o11y (dogstatsd metrics)
# ---------------------------------------------------------------------------
cmd_install_agent_byoc() {
  require_env CLUSTER REGION PROFILE SITE NAMESPACE
  need_cmd aws; need_cmd kubectl; need_cmd helm; need_cmd envsubst

  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" $PROFILE

  export CLUSTER
  local values_file="$SCRIPT_DIR/cp-dd-agent-values.yaml"
  log "Writing $values_file"
  cat << 'EOF' > "$values_file"
# https://github.com/DataDog/helm-charts/blob/main/charts/datadog/values.yaml
datadog:
  apiKeyExistingSecret: datadog-secret
  env:
      - name: DD_LOGS_CONFIG_LOGS_DD_URL
        value: http://datadog-byoc-cloudprem-indexer.byoclogs.svc.cluster.local:7280
      - name: DD_LOGS_CONFIG_EXPECTED_TAGS_DURATION
        value: "100000"
  logs:
    enabled: true
    containerCollectAll: true
    autoMultiLineDetection: true
EOF
  envsubst < "$values_file" > "${values_file}.rendered"

  log "Installing datadog-agent for BYOC cluster o11y"
  helm upgrade --install datadog-agent datadog/datadog \
    --namespace $NAMESPACE -f "${values_file}.rendered"

  log "Metrics: https://app.${SITE}/metric/summary?filter=cloudprem"
  log "Dashboard: https://app.${SITE}/dash/integration/32086/datadog-cloudprem (may take up to 15 min)"
}

# ---------------------------------------------------------------------------
# cleanup: delete everything, in reverse order
# ---------------------------------------------------------------------------
cmd_cleanup() {
  require_env WORKLOAD_CLUSTER DB_IDENTIFIER DB_SUBNET_GROUP BUCKET CLUSTER REGION PROFILE
  need_cmd aws; need_cmd eksctl

  aws configure sso

  warn "This will delete: workload cluster $WORKLOAD_CLUSTER, RDS instance $DB_IDENTIFIER,"
  warn "DB subnet group $DB_SUBNET_GROUP, S3 bucket $BUCKET, cluster $CLUSTER, and IAM policy $POLICY_NAME (if set)."
  read -r -p "Type 'yes' to continue: " confirm
  [ "$confirm" = "yes" ] || die "Aborted."

  #log "Deleting workload cluster $WORKLOAD_CLUSTER"
  #eksctl delete cluster --name "$WORKLOAD_CLUSTER" --region "$REGION" $PROFILE
  set +e
  log "Deleting RDS instance $DB_IDENTIFIER (no snapshot)"
  aws rds delete-db-instance \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --region "$REGION" $PROFILE --skip-final-snapshot \
    > /dev/null

  log "Waiting for DB deletion before removing subnet group..."
  while aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" \
    --region "$REGION" $PROFILE >/dev/null 2>&1; do
    sleep 10
  done

  log "Deleting DB subnet group $DB_SUBNET_GROUP"
  aws rds delete-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --region "$REGION" $PROFILE \
    > /dev/null

  log "Deleting S3 bucket $BUCKET"
  aws s3 rb "s3://$BUCKET" --region "$REGION" $PROFILE --force
  set -e

  log "Deleting cluster $CLUSTER"
  eksctl delete cluster --name "$CLUSTER" --region "$REGION" --disable-nodegroup-eviction $PROFILE

  log "Looking up policy ARN"
  POLICY_ARN=$(aws iam list-policies --query \
    "Policies[?PolicyName=='${POLICY_NAME}'].Arn" \
    --region $REGION $PROFILE --output text)
  echo "policy arn: $POLICY_ARN"
  export POLICY_ARN
  log "POLICY_ARN=$POLICY_ARN"

  if [ -n "${POLICY_ARN:-}" ]; then
    log "Deleting IAM policy $POLICY_ARN"
    aws iam delete-policy --policy-arn "$POLICY_ARN" --region "$REGION" $PROFILE
  else
    warn "POLICY_ARN not set in this shell; delete the IAM policy manually if needed:"
    warn "  aws iam list-policies --query \"Policies[?PolicyName=='\$POLICY_NAME'].Arn\" --output text $PROFILE"
  fi

  log "Looking up policy ARN for policy $AWS_LB_ControllerIAMPolicy"
  POLICY_ARN=$(aws iam list-policies --query \
    "Policies[?PolicyName=='${AWS_LB_ControllerIAMPolicy}'].Arn" \
    --region $REGION $PROFILE --output text)
  
  export POLICY_ARN
  log "POLICY_ARN=$POLICY_ARN"

  if [ -n "${POLICY_ARN:-}" ]; then
    log "Deleting IAM policy $POLICY_ARN"
    aws iam delete-policy --policy-arn "$POLICY_ARN" --region "$REGION" $PROFILE
  else
    warn "POLICY_ARN not set in this shell; delete the IAM policy manually if needed:"
    warn "  aws iam list-policies --query \"Policies[?PolicyName=='\$POLICY_NAME'].Arn\" --output text $PROFILE"
  fi

  log "Cleanup complete."
}

# ---------------------------------------------------------------------------
# all: run the fully-automatable happy path (BYOC cluster + workload cluster + sg)
# ---------------------------------------------------------------------------
cmd_all() {
  cmd_create_cluster
  cmd_create_rds
  cmd_create_s3
  cmd_create_iam
  cmd_install_lb_controller
  cmd_install_byoc
  cmd_install_agent_byoc
  #cmd_create_workload_cluster
  #cmd_setup_sg
  log "Automated portion complete."
  warn "Next manual steps: run '$0 create-op-pipeline', then '$0 install-op',"
  warn "then '$0 install-agent-workload', '$0 generate-load', '$0 redact-sensitive-data',"
  warn "and '$0 install-agent-byoc'."
}

usage() {
  cat <<EOF
Usage: $0 <command>

Setup (in order):
  init-env               Write default .env with the lab's variables
  create-cluster          Create the BYOC/OP EKS cluster + oidc + addons
  create-rds              Create the RDS postgres metastore
  create-s3               Create the S3 bucket for indexes
  create-iam              Create IAM policy + iamserviceaccount for S3 access
  install-lb-controller   Install the AWS Load Balancer Controller
  install-byoc            Install the BYOC Logs (cloudprem) helm chart
  create-workload-cluster Create the second (workload) EKS cluster
  setup-sg                Create shared SG allowing workload -> OP LB traffic
  create-op-pipeline      [manual UI] create the OP pipeline, capture pipeline ID
  install-op              Install the Observability Pipelines Worker
  install-agent-workload  Install DD agent on the workload cluster (-> OP)
  generate-load           Deploy microservices-demo to generate log volume
  redact-sensitive-data   [manual UI] add Sensitive Data Scanner processor
  install-agent-byoc      Install DD agent on the BYOC cluster (dogstatsd metrics)
  all                     Run create-cluster through setup-sg in order
  cleanup                 Tear down all created resources

Run 'source $ENV_FILE' (after 'init-env') before running other commands.
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "$cmd" in
    init-env)               cmd_init_env "$@" ;;
    create-cluster)         cmd_create_cluster "$@" ;;
    create-rds)             cmd_create_rds "$@" ;;
    create-s3)              cmd_create_s3 "$@" ;;
    create-iam)             cmd_create_iam "$@" ;;
    install-lb-controller)  cmd_install_lb_controller "$@" ;;
    install-byoc)           cmd_install_byoc "$@" ;;
    create-workload-cluster) cmd_create_workload_cluster "$@" ;;
    setup-sg)               cmd_setup_sg "$@" ;;
    create-op-pipeline)     cmd_create_op_pipeline "$@" ;;
    install-op)             cmd_install_op "$@" ;;
    install-agent-workload) cmd_install_agent_workload "$@" ;;
    generate-load)          cmd_generate_load "$@" ;;
    redact-sensitive-data)  cmd_redact_sensitive_data "$@" ;;
    install-agent-byoc)     cmd_install_agent_byoc "$@" ;;
    all)                    cmd_all "$@" ;;
    cleanup)                cmd_cleanup "$@" ;;
    help|-h|--help)         usage ;;
    *) warn "Unknown command: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
