"""
Add lambda triggers to send CloudTrail logs to Datadog
"""

import json
import sys
import time
import requests
import boto3

ERROR = -1
INCREMENT = 1

def main():
    """
    Main method
    """
    # open, read, get config
    file_object = open('config.json', 'r', encoding="utf-8")
    config_data = json.load(file_object)
    aws_lambda_region = (config_data['aws_lambda_region'])
    aws_region = (config_data['region'])
    add_cloudtrail = (config_data['add_cloudtrail'])
    remove_cloudtrail = (config_data['remove_cloudtrail'])
    file_object.close()

    datadog_forwarder_arn = None

    for iterator in aws_region:

        if add_cloudtrail == remove_cloudtrail:
            print("Add and remove cloudtrail can't both be true... exiting...\n")
            sys.exit()

        lambda_client = boto3.client('lambda', region_name = iterator)

        #get lambda functions for region
        response = lambda_client.list_functions()

        datadog_forwarder_name = None

        try:
            #get arn for forwarder
            for i in range(len(response['Functions'])):
                if response['Functions'][i]['FunctionName'] \
                    == "datadog-forwarder":
                    datadog_forwarder_name = response['Functions'][i]['FunctionName']
                    datadog_forwarder_arn = response['Functions'][i]['FunctionArn']
                    break

            if datadog_forwarder_name is None:
                raise AttributeError

        except AttributeError as exception:
            exception = str(exception)
            print("Exception getting Datadog Lambda forwarder information in " + \
                iterator + ", adding to " + iterator + " from " +
                aws_lambda_region + " ... " + exception + "\n")

            try:
                if datadog_forwarder_name is None:
                    datadog_forwarder_name = "datadog-forwarder"

                #get client where lambda is
                lambda_client = boto3.client('lambda', region_name=aws_lambda_region)

                #get what we need to add lambda forwarder to region
                response = lambda_client.get_function(
                    FunctionName=datadog_forwarder_name
                    )

                lambda_runtime = "python3.8"
                layer = response['Configuration']['Layers'][0]['Arn']
                #change region for layer for new lambda
                layer = layer.replace(aws_lambda_region, iterator)
                role = response['Configuration']['Role']
                handler = response['Configuration']['Handler']
                datadog_forwarder_arn = response['Configuration']['FunctionArn']
                datadog_forwarder_arn = datadog_forwarder_arn.replace(
                    aws_lambda_region, iterator)

                dd_forwarder = "https://github.com/DataDog/datadog-server" + \
                "less-functions/archive/refs/tags/aws-dd-forwarder-3.53.0.zip"
                response = requests.get(dd_forwarder)
                open("aws-dd-forwarder-3.53.0.zip", "wb").write(response.content)

                with open('aws-dd-forwarder-3.53.0.zip', 'rb') as file_object:
                    zipped_code = file_object.read()

                #set region to new lambda region and create function
                lambda_client = boto3.client('lambda', region_name = iterator)

                response = lambda_client.create_function(
                    FunctionName=datadog_forwarder_name,
                    Runtime=lambda_runtime,
                    Role=role,
                    Handler=handler,
                    Code=dict(ZipFile=zipped_code),
                    Timeout=300,
                    Layers=[ layer ]
                )
            #TODO add actual exception
            except Exception as inner_exception:
                inner_exception = str(inner_exception)
                print("Exception adding Datadog Lambda forwarder in " + \
                    iterator + ", exiting... " + inner_exception + "\n")
                sys.exit()

        #region_name does not seem to do anything here - may look at later so don't have
        #do loop
        cloudtrail_client = boto3.client('cloudtrail')
        response = cloudtrail_client.describe_trails()

        #get bucket for logs
        count = 0
        cloudtrail_bucket_name = None

        for key,value in response.items():
            if response['trailList'][count]['HomeRegion'] == iterator:
                cloudtrail_bucket_name = response['trailList'][count]['S3BucketName']
                break
            count += INCREMENT

        #bucket_arn_prefix = "arn:aws:s3:::"
        statement_id_prefix = "datadog_cloudtrail_permission_"

        s3_client = boto3.client('s3')

        if bool(add_cloudtrail):
            #ensure region is where will add trigger
            datadog_forwarder_arn = datadog_forwarder_arn.replace(
                    aws_lambda_region, iterator)

            #add execute permission for trigger
            if datadog_forwarder_arn is not None and \
                cloudtrail_bucket_name is not None:
                response = lambda_client.add_permission(
                    FunctionName = datadog_forwarder_arn,
                    StatementId = statement_id_prefix + iterator,
                    Action = "lambda:InvokeFunction",
                    Principal = "s3.amazonaws.com",
                    SourceArn = "arn:aws:s3:::" + cloudtrail_bucket_name)

                #this seems to solve a race condition where the permission is
                #not available sometimes before the next call.  TODO: check
                #permission until available then make next call
                time.sleep(10)

                #add trigger
                response = s3_client.put_bucket_notification_configuration(
                    Bucket = cloudtrail_bucket_name,
                    NotificationConfiguration = {
                                            'LambdaFunctionConfigurations':
                                            [{"Id":
                                                "lambda-s3-event-configuration",
                                                'LambdaFunctionArn':
                                                    datadog_forwarder_arn,
                                            'Events': ['s3:ObjectCreated:*'],
                                            "Filter":
                                            {
                                                "Key":
                                                    {
                                                        "FilterRules":
                                                            [
                                                                {"Name": "suffix",
                                                                "Value": ""
                                                                }
                                                            ]
                                                    }
                                            }}]}
                    )

                print("CloudTrail logs configured to send to Datadog for bucket " \
                    + cloudtrail_bucket_name + \
                    " in region " + iterator + "\n")
            else:
                print("No Datadog Lambda forwarder name and/or cloudtrail " + \
                    "bucket name or add is false... Exiting...\n")
                sys.exit(ERROR)

        try:
            #remove permission and trigger and added lambdas
            if bool(remove_cloudtrail):
                try:
                    response = lambda_client.remove_permission(
                        FunctionName = datadog_forwarder_arn,
                        StatementId = statement_id_prefix + iterator
                    )
                #TODO look at bringing in exception from botocore
                except Exception as rpnf_eception:
                    rpnf_eception = str(rpnf_eception)
                    print(rpnf_eception + " Exiting...\n")
                    sys.exit(ERROR)

                response = s3_client.put_bucket_notification_configuration(
                    Bucket = cloudtrail_bucket_name,
                    NotificationConfiguration = {'LambdaFunctionConfigurations': []}
                    )

                if iterator != aws_lambda_region:
                    response = lambda_client.delete_function(
                            FunctionName=datadog_forwarder_name
                        )

                print("Removing permission, trigger and lambda (for all but " + \
                    aws_lambda_region + ") for " + cloudtrail_bucket_name + \
                    " in " + iterator + ".\n")
        #TODO add actual exception
        except IndexError as exception:
            exception = str(exception)
            print("Exception, exiting... " + exception + "\n")
            sys.exit(ERROR)

if __name__ == "__main__":
    main()
