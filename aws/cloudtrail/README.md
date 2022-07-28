Configure AWS Regions in an Account to Forward CloudTrail Logs to Datadog
--

This repository will configure all regions in an AWS account to forward logs
to Datadog.  Optionally, the Datadog AWS integration, Cloud SIEM as well as CSPM
 can be configured.  

Requirements
--

1) terraform - see the Datadog Provider
[documentation](https://registry.terraform.io/providers/DataDog/datadog/latest/docs)
for requirements.  

2) python3  

Files
--

1) config.json - configuration for configure_cloudtrail_logs.py  
  - aws_lambda_region (string) - region where the datadog forwarder was
  installed using the lambda_forwarder repository
  [here](https://github.com/jgibbons-cp/datadog/tree/main/aws/lambda_forwarder).  
  - region (array of string(s)) - regions where CloudTrail logs will be
  configured to be forwarded.  
  - add_cloudtrail - 1 to configure logs or 0 if the configuration will be
  removed
  - remove_cloudtrail - 1 to configure logs for remove or 0 if the configuration
  will be added  

2) configure_cloudtrail_logs.py - script  

3) configure_account.sh - script to put pieces together (add Datadog AWS
  integration, add lambda forwarder, setup cloudtrail logs)  

4) env_vars.sh - environment variables for terraform (Datadog API/APP key)  

Process
--

1) If you don't want to manually enter the Datadog API/APP keys, add
   [them](https://app.datadoghq.com/organization-settings/users) to
   env_vars.sh so they can be sourced and passed in the script to terraform.  

2) In configure_account.sh choose wether to install the Datadog AWS integration.
   The default is set to ```true```.  This will collect metrics, resources,
   and CSPM.  If you don't want to setup the AWS integration set this to
   ```
   false
   ```
  .  

3) Setup or Destroy - In configure_account.sh setup is the default.  To
teardown set ```TEARDOWN="-destroy"```  

4) In configure_account.sh configure the paths to the required repositories
(PATH_TO_DD_AWS_INTEGRATION_REPO and PATH_TO_DD_LAMBDA_FORWARDER_REPO)  

5) In config.json setup your configuration - see variables above.  

Run
--

sh configure_account.sh  

Have fun!
