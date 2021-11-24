CLI Instructions to Create an AKS Stack with Linux and Windows Worker Nodes  
--  

Instructions - taken from
[here](https://docs.microsoft.com/en-us/azure/aks/windows-container-cli).  
--  

1) Login to use the CLI   

```
az login
```

2) Create a resource group  

```
az group create \
        --name RESOURCE_GROUP_NAME \
        --location REGION
```  

3) Create a Cluster  

```
az aks create \
        --resource-group RESOURCE_GROUP_NAME \
        --name CLUSTER_NAME \
        --node-count 2 \
        --enable-addons monitoring \
        --generate-ssh-keys \
        --windows-admin-username USERNAME \
        --vm-set-type VirtualMachineScaleSets \
        --kubernetes-version 1.20.7 \
        --network-plugin azure
```  

After running this provide a Windows Admin password to kick off the deployment.  

4) Add a Windows nodepool  

```
az aks nodepool add \
        --resource-group RESOURCE_GROUP_NAME \
        --cluster-name CLUSTER_NAME \
        --os-type Windows \
        --name NODEPOOL_NAME \
        --node-count 2
```  

5) Get credentials  

```
sudo az aks get-credentials \
        --resource-group RESOURCE_GROUP_NAME \
        --name CLUSTER_NAME
```  

6)  Look at cluster... NOTE: not sure why I have to use sudo on kubectl and
helm... messed with a bit then gave up.  If you know why please ping me or
submit a PR.  

```
sudo kubectl get nodes
```

```
NAME        STATUS   ROLES   AGE     VERSION OS-IMAGE  
aks-xxx-0   Ready    agent   24m     v1.20.7 Ubuntu 18.04.6 LTS  
aks-xxx-1   Ready    agent   23m     v1.20.7 Ubuntu 18.04.6 LTS  
aksxxx0     Ready    agent   7m23s   v1.20.7 Windows Server 2019 Datacenter  
aksxxx1     Ready    agent   8m16s   v1.20.7 Windows Server 2019 Datacenter  
```

7) Create secrets for agent using keys from
[here](https://app.datadoghq.com/organization-settings/users).  

```
sudo kubectl create secret generic datadog-agent \
        --from-literal api-key=<key> \
        --from-literal app-key=<key>
```  

8) Install Linux Datadog agent from
[here](https://docs.datadoghq.com/agent/kubernetes/?tab=helm)  

In values.yaml set the following:  

```
clusterName:  CLUSTER_NAME    
tlsVerify: false  
portEnabled: true #under apm  
```

```
sudo helm repo add datadog https://helm.datadoghq.com  
sudo helm repo update  
sudo helm install dd-agent -f values.yaml datadog/datadog  
```  

9) Install Windows Datadog agent

In values_win.yaml set the following:  

```
clusterName:  CLUSTER_NAME  
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
serviceName:  dd-agent-datadog-cluster-agent #under existingClusterAgent:  
tokenSecretName: dd-agent-dat888adog-cluster-agent#under existingClusterAgent:  
```

```
sudo helm install dd-agent-win -f values.yaml datadog/datadog
```  

10) [Trace](https://github.com/jgibbons-cp/datadog/tree/main/kubernetes/aspnet48_mvc_app)
a Windows .NET application in Datadog  

11) Need to connect to a node - see
[here](https://docs.microsoft.com/en-us/azure/aks/rdp)  

12) Delete the cluster  

```
az group delete \
        --name RESOURCE_GROUP_NAME \
        --yes \
        --no-wait
```
