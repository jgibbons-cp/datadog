Bring Your Own Cloud (BYOC) - Azure Kubernetes Service (AKS) Lab
--

This lab will configure a one node lab for BYOC on AKS.
  
Testing
--

Macintosh OSX  
  
Pre-Requisites
--

1) [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/?view=azure-cli-latest)  
2) [Helm](https://helm.sh/)  
3) [kubectl](https://kubernetes.io/docs/reference/kubectl/)  

Configuration
--

The hidden file .env stores configuration variables.  
  
- Defaults - most likely to be changed by the user  
  - BYOC_LOGS_LOCATION="westus"  
  - BYOC_LOGS_AKS_NODE_SIZE=Standard_E16s_v6  
  - BYOC_LOGS_POSTGRES_NODE_SIZE=Standard_D4ds_v5  

- Need configuration  
  - API_KEY= # can be located in the [Datadog UI](https://app.datadoghq.com/organization-settings/api-keys)  

Usage
--

```  
# setup  
bash create_lab.sh.sh  
  
# teardown  
bash cleanup_lab.sh  
```  
