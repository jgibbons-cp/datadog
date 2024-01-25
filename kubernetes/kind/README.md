Create a Kind K8 Cluster
--

These scripts will create and delete a Kind Kubernetes cluster.  

Requirements
-

1) docker  
  
Files
-

1) create_kind.sh - create a kind cluster (defaults to a control plane
and worker node)  

2) delete_kind.sh - delete cluster  

3) config.yaml - cluster configuration.  For more configuration options
see the
[documentation](https://kind.sigs.k8s.io/docs/user/quick-start/#configuring-your-kind-cluster).  

Startup with KUBECONFIG Set
--
  
source ./set_kubeconfig.sh && sh create_kind.sh  
