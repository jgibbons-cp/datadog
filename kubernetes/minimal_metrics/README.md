Minimal Kubernetes Metrics
--

License for Repository: [Apache](https://github.com/jgibbons-cp/datadog/blob/main/LICENSE) 
  
This is an initial pass for decreasing Kubernetes, and default, metrics from the Datadog agent(s). Often this is done to decrease traffic for a limited pipe to the Internet.  
  
Based on the license, use is as-is.  
  
As a guideline, it is up to the user to review and determine the minimal set of metrics needed for observability. Not all objects may be relevant (e.g. do you use pod autoscaling). It is also up to the user to test, in a lower environment, that the observability that is needed is provided by the metrics.  
  
* MinimalKubernetesMetrics.xls: this is in Excel format because it is easy to navigate, the colors are helpful and works on a Mac.  
  
  * Metrics. 
    * [Kubernetes Metrics](https://docs.datadoghq.com/containers/kubernetes/data_collected/#kubernetes): kubernetes.*  
    * [Kubelet metrics](https://docs.datadoghq.com/containers/kubernetes/data_collected/#kubelet): kubernetes.*  
    * [Kubernetes State Metrics Core](https://docs.datadoghq.com/containers/kubernetes/data_collected/#kubernetes-state-metrics-core): kubernetes_state.* NOTE: [kube-state-metrics](https://docs.datadoghq.com/containers/kubernetes/data_collected/#kubernetes-state) is deprecated and is turned off by default (e.g. helm values).  If you turned this on turn it off.  
    * [Kubernetes DNS](https://docs.datadoghq.com/containers/kubernetes/data_collected/#kubernetes-dns): kubedns.*. 
    * [Kubernetes Proxy](https://docs.datadoghq.com/containers/kubernetes/data_collected/#kubernetes-proxy): kubeproxy.*  
    * [Kubernetes API Server](https://docs.datadoghq.com/containers/kubernetes/data_collected/#kubernetes-api-server): kube_apiserver.*  
    * [Kubernetes Controller Manager](https://docs.datadoghq.com/containers/kubernetes/data_collected/#kubernetes-controller-manager): kube_controller_manager.*  
    * [Kubernetes Metrics Server](https://docs.datadoghq.com/containers/kubernetes/data_collected/#kubernetes-metrics-server): kube_metrics_server.*  
    * [Kubernetes Scheduler](https://docs.datadoghq.com/containers/kubernetes/data_collected/#kubernetes-scheduler): kube_scheduler.*  
    * [Container Metrics](https://docs.datadoghq.com/integrations/container/#metrics): container.* NOTE: if you want to get to the container level you can aggregate from kubernetes.* to get down to tag based granularity (e.g. group_by:container_name)  
    * [Containerd metrics](https://docs.datadoghq.com/integrations/containerd/?tab=linuxcontainer#metrics): containerd.*  
    * [CoreDNS](https://docs.datadoghq.com/integrations/coredns/?tab=docker#metrics): coredns.* This is an agent integration, so if you don't want any of the metrics you can turn it off in the agent or cherry pick with either [Vector](https://vector.dev/) or [OP](https://docs.datadoghq.com/observability_pipelines/?tab=logs).  For example with Helm:  
      
      ```  
      # [values](https://github.com/DataDog/helm-charts/blob/main/charts/datadog/values.yaml#L1298-#L1303) file  
      datadog:  
        ignoreAutoConfig:  
          - coredns  
      ```  
    * [CRI metrics](https://docs.datadoghq.com/integrations/cri/#metrics): cri.*  
    * Datadog metrics: datadog.*  
    * [NTP Metric](https://docs.datadoghq.com/integrations/ntp/?tab=host): ntp.* NOTE: NTP is important for time-series data.  See the linked documentation.  
    * [Synthetics - Browser Tests](https://docs.datadoghq.com/continuous_testing/metrics/#browser-tests): synthetics.browser.*  
    * [System Metrics](https://docs.datadoghq.com/integrations/system/#data-collected): system.*  