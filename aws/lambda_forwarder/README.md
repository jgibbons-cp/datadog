Add the Lamda Forwarder to Support Log Collection to an AWS Account
--

Using the
[Datadog terraform provider](https://registry.terraform.io/providers/DataDog/datadog/latest/docs)
 and the [datadog_integration_aws_lambda_arn (Resource)](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/integration_aws_lambda_arn), add the Datadog Lambda Forwarder
 to an AWS account to support log forwarding to a Datadog organization.  

1) variables.tf - variables for apply  
  - TF_VAR_DD_API_KEY - environment variable that can be used for the Datadog
    API key.  If not present it is required via stdin.  
  - TF_VAR_DD_APP_KEY - environment variable that can be used for the Datadog
    APP key.  If not present it is required via stdin.  
  - AWS credentials are pulled from standard AWS CLI configuration  

Usage (as noted in the documentation, the resource does not support updates):  

$ terraform plan  
$ terraform apply  
