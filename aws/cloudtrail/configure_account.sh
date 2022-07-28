#!/bin/#!/usr/bin/env bash

#if want to load env vars
source ./env_vars.sh

#if want to teardown the terraform resources, set to -destroy
TEARDOWN=""

INSTALL_DD_AWS_INTEGRATION=true
PATH_TO_DD_AWS_INTEGRATION_REPO="/Users/jenks.gibbons/Documents/\
datadog-experience/deployment/terraform/aws-datadog"
PATH_TO_DD_LAMBDA_FORWARDER_REPO="/Users/jenks.gibbons/Documents/\
vivent/datadog/aws/lambda_forwarder"

#set to empty if don't want to auto-approve terraform apply
AUTO_APPROVE="-auto-approve"

#TODO: maybe add possible user input it wanted for checking aws creds/account
#aws sts get-caller-identity

#need terraform
command -v terraform > /dev/null

if [ $? = 1 ]
then
  echo "Exiting, install terraform to use... The required version can be found\
  at https://registry.terraform.io/providers/DataDog/datadog/latest/docs\n"
fi

if [ $INSTALL_DD_AWS_INTEGRATION = true ]
then
    #cd
    pushd $PATH_TO_DD_AWS_INTEGRATION_REPO > /dev/null

    #TODO maybe add plan if we have user inputs added
    #install dd aws integration
    terraform init
    terraform apply $TEARDOWN $AUTO_APPROVE \
      -var datadog_api_key=$TF_VAR_DD_API_KEY \
      -var datadog_app_key=$TF_VAR_DD_APP_KEY

    #and back
    popd > /dev/null
fi

#cd
pushd $PATH_TO_DD_LAMBDA_FORWARDER_REPO > /dev/null

#install lambda forwarder in a aws region
terraform init
terraform apply $TEARDOWN $AUTO_APPROVE \
  -var datadog_api_key=$TF_VAR_DD_API_KEY \
  -var datadog_app_key=$TF_VAR_DD_APP_KEY

#and back
popd > /dev/null

#configure cloudtrail logs
python configure_cloudtrail_logs.py
