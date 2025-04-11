Datadog <> EKS on Fargate Configuration  
---

Configuration  
--

The following outlines how to collect data from your applications running in AWS EKS Fargate.

1) Set up AWS EKS Fargate RBAC rules.
2) Deploy the Agent as a sidecar.

AWS EKS Fargate RBAC
--

When deploying the agent as a sidecar, you'll need to apply the following RBAC.
  
```  
apiVersion: rbac.authorization.k8s.io/v1  
kind: ClusterRole  
metadata:  
  name: datadog-agent  
rules:  
  - apiGroups:  
    - ""  
    resources:  
    - nodes  
    - namespaces  
    - endpoints  
    verbs:  
    - get  
    - list  
  - apiGroups:  
      - ""  
    resources:  
      - nodes/metrics  
      - nodes/spec  
      - nodes/stats  
      - nodes/proxy  
      - nodes/pods  
      - nodes/healthz  
    verbs:  
      - get  
---  
apiVersion: rbac.authorization.k8s.io/v1  
kind: ClusterRoleBinding  
metadata:  
  name: datadog-agent  
roleRef:  
  apiGroup: rbac.authorization.k8s.io  
  kind: ClusterRole  
  name: datadog-agent  
subjects:  
  - kind: ServiceAccount  
    name: datadog-agent  
    namespace: <application_namespace>  
---  
apiVersion: v1  
kind: ServiceAccount  
metadata:  
  name: datadog-agent  
  namespace: <application_namespace>  
```  
  
Running the Agent as a Sidecar  
--
  
The installation method will be the Datadog Operator. There are a few prerequisites for this step:  
  
1) Set up RBAC in the application namespace(s) as shown above. The RBAC is applied to the application namespace so the agent can use the service account.  
  
2) Install the operator  
  
```  
helm repo add datadog https://helm.datadoghq.com  
helm install datadog-operator datadog/datadog-operator -n <namespace>  
```  
  
3) Create a Kubernetes secret containing your Datadog API key and Cluster Agent token (32 character string) in the Datadog installation and application namespaces.  
  
```  
$ kubectl create secret generic datadog-secret -n <agent_namespace> --from-literal api-key=<YOUR_DATADOG_API_KEY> --from-literal token=<CLUSTER_AGENT_TOKEN>  
  
$ kubectl create secret generic datadog-secret -n <app_namespace> --from-literal api-key=<YOUR_DATADOG_API_KEY> --from-literal token=<CLUSTER_AGENT_TOKEN>  
```  

3) Create the DatadogAgent resource (example datadog-agent.yaml below):
  
```  
apiVersion: datadoghq.com/v2alpha1  
kind: DatadogAgent  
metadata:  
  name: datadog  
  namespace: <applicaation_namespace>  
spec:  
  global:  
    clusterName: fargate-usw2 #<cluster_name>
    clusterAgentTokenSecret:  
      secretName: datadog-secret  
      keyName: token  
    credentials:  
      apiSecret:  
        secretName: datadog-secret  
        keyName: api-key  
  features:  
    admissionController:  
      agentSidecarInjection:  
        enabled: true  
        provider: fargate  
```  
  
4) Apply the configuration:  

```
$ kubectl apply -f datadog-agent.yaml  
```  
  
This will create the cluster agent which will inject the sidecar agents into the application pods that have the pod label:  
  
```  
agent.datadoghq.com/sidecar: fargate  
```  
