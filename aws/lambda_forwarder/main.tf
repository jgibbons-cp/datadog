terraform {
  required_providers {
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

provider "datadog" {
  api_key = var.DD_API_KEY
  app_key = var.DD_APP_KEY
}

provider "aws" {
  region                   = var.aws_region
  profile                  = var.aws_profile
}

data "aws_caller_identity" "current" {}

####
# https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/integration_aws_lambda_arn
####
resource "datadog_integration_aws_lambda_arn" "main_collector" {
  account_id  = data.aws_caller_identity.current.account_id
  lambda_arn = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:datadog-forwarder"
}

# Datadog Forwarder lambda installation
# https://github.com/DataDog/datadog-serverless-functions/tree/master/aws/logs_monitoring
resource "aws_cloudformation_stack" "datadog_forwarder" {
  name         = "datadog-forwarder"
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM", "CAPABILITY_AUTO_EXPAND"]
  parameters   = {
    DdApiKey  = var.DD_API_KEY,
    DdSite             = "datadoghq.com",
    FunctionName       = "datadog-forwarder"
  }
  template_url = "https://datadog-cloudformation-template.s3.amazonaws.com/aws/forwarder/latest.yaml"
}
