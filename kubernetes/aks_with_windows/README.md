CLI Instructions to Create an AKS Stack with Linux and Windows Worker Nodes  
--  

Instructions - taken from
[here](https://docs.microsoft.com/en-us/azure/aks/windows-container-cli).  
--  

1) `az login`

2) Create a resource group  

`az group create --name \<RESOURCE_GROUP_NAME\> --location \<REGION\>`  

3) Create a Cluster  

`az aks create \
    --resource-group \<RESOURCE_GROUP_NAME\> \
    --name \<CLUSTER_NAME\> \
    --node-count 2 \
    --enable-addons monitoring \
    --generate-ssh-keys \
    --windows-admin-username \<USERNAMER\> \
    --vm-set-type VirtualMachineScaleSets \
    --kubernetes-version 1.20.7 \
    --network-plugin azure
`  

After running this provide a Windows Admin password to kick off the deployment.  

4) Add a Windows nodepool  

`az aks nodepool add \
    --resource-group \<RESOURCE_GROUP_NAME\> \
    --cluster-name \<CLUSTER_NAME\> \
    --os-type Windows \
    --name \<NODEPOOL_NAME\> \
    --node-count 2
`  

5) Get credentials  

`sudo az aks get-credentials --resource-group \<RESOURCE_GROUP_NAME\> --name \<CLUSTER_NAME\>`  

6)  Look at cluster... NOTE: not sure why I have to use sudo on kubectl and
helm... messed with a bit then gave up.  If you know why please ping me or
submit a PR.  

`sudo kubectl get nodes`

`NAME        STATUS   ROLES   AGE     VERSION OS-IMAGE
aks-xxx-0   Ready    agent   24m     v1.20.7 Ubuntu 18.04.6 LTS
aks-xxx-1   Ready    agent   23m     v1.20.7 Ubuntu 18.04.6 LTS
aksxxx0     Ready    agent   7m23s   v1.20.7 Windows Server 2019 Datacenter
aksxxx1     Ready    agent   8m16s   v1.20.7 Windows Server 2019 Datacenter`  

7) Taint the Windows nodes for Datadog agent install  

`sudo kubectl taint node <node> node.kubernetes.io/os=windows:NoSchedule`  

8) Create secrets for agent using keys from
[here](https://app.datadoghq.com/organization-settings/users).  

`sudo kubectl create secret generic datadog-agent --from-literal api-key=\<key\> --from-literal app-key=\<key\>`  

9) Install Linux Datadog agent from
[here](https://docs.datadoghq.com/agent/kubernetes/?tab=helm)  

In values.yaml set the following:  

`clusterName:  \<cluster_name\>  
tlsVerify: false
portEnabled: true #under apm  `

`sudo helm repo add datadog https://helm.datadoghq.com
sudo helm repo update
sudo helm install dd-agent -f values.yaml datadog/datadog`

10) Install Windows Datadog agent

In values_win.yaml set the following:  

`clusterName:  \<cluster_name\>  
tlsVerify: false
portEnabled: true #under apm  
kubeStateMetricsEnabled: false
nonLocalTraffic: true
leaderElection: false
enabled: true #under orchestratorExplorer:
enabled: false #under Cluster Agent
enabled: true #under metrics provider
enabled: true #under Admissions controller
join: true #under existingClusterAgent:
serviceName:  dd-agent-datadog-cluster-agent`

`sudo helm install dd-agent-win -f values.yaml datadog/datadog`  
