CD for a K8 Web App
--

- Tested on Ubuntu 22.04 and MacOSX Ventura 13.2.  
- Only tested on deployment  
- Access to applicaton is via kubectl port-forward  
  
This application is for testing Kubernetes local changes to deployments in a local development environment.  It is also incorporated into the checkin process for a local webapp [app-java](https://github.com/jgibbons-cp/datadog/tree/main/app-java) using the workflow [here](https://github.com/jgibbons-cp/datadog/blob/main/.github/workflows/deploy_test.yml).  
  
Pre-Requisites
--

1) git  
2) docker  
3) npm  
4) kubectl  
5) [datadog-ci](https://www.npmjs.com/package/@datadog/datadog-ci)
6) Python modules -  
  
* datadog-api-client  
* pyyaml  
* requests  
* gitpython  
* kubernetes  
  
Configuration
--

```
# this is used for app-java RUM to set values for the Datadog tokens  
secret:
  - generic:
      name: dd-rum-tokens
      secret_key_0: "APPLICATION_ID"
      value_0: <APPLICATION_ID>
      secret_key_1: "CLIENT_TOKEN"
      value_1: <CLIENT_TOKEN>

# all manifests in deployment - three here as app-java has three  
application:
  - object:
      manifest: <MANIFEST_1>
      namespace: <NAMESPACE>
      label_selector: <LABEL_SELECTOR_1>
  - object:
      manifest: <MANIFEST_2>
      namespace: <NAMESPACE>
      label_selector: <LABEL_SELECTOR_2>
  - object:
      manifest: <MANIFEST_3>
      namespace: ""
      label_selector: ""

# path is relative to dev directory  
cicd_functions:
  module_relative_path: "../cicd_functions.py"

# Datadog [CI configuration](https://docs.datadoghq.com/continuous_testing/cicd_integrations/configuration/?tab=npm)
browser_test:
  skip: False
  # test to run
  id_config: "cicd.synthetics.json"
  # start url and tunnel option
  tunnel_config: "datadog-ci.json"
  # public id of test from browser test UI in Datadog
  public_id: <BROWSER_TEST_PUBLIC_ID>
  # tunnel port
  tunnel_port: <BROWSER_TEST_TUNNEL_PORT>
  # app port
  app_port: <BROWSER_TEST_APP_PORT>

# port forward type and name (e.g. deploy/app-java)
port_forward:
  type_name: <PORT_FORWARD_TYPE_NAME>

# local functions
modules:
  cicd: "./local_cicd_functions.py"
  module_relative_path: "../cicd_functions.py"

# service name (e.g. app-java, petclinic)
service:
  name: <SERVICE_NAME>
```