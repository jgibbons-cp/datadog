Minimal Kubernetes Metrics
--

License: Apache 
  
This is a base set of guidelines for decreasing Kubernetes metrics from the Datadog agent. Often this is done to decrease traffic for a limited pipe to the Internet.  
  
Based on the license, use is as-is.  
  
As a guideline, it is up to the user to review and determine the minimal set of metrics needed for observability. Not all objects may be relevant (e.g. do you use pod autoscaling). It is also up to the user to test, in a lower environment, that the observability that is needed is provided by the metrics.  

