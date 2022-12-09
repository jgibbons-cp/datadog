'''k8 cicd functions'''
import json
import os
import shutil
import socket
import urllib.request
import requests

import git
from kubernetes import client, utils
from python_terraform import Terraform
from datadog_api_client.exceptions import NotFoundException
from datadog_api_client import ApiClient, Configuration
from datadog_api_client.v2.api.logs_api import LogsApi
from datadog_api_client.v1.api.synthetics_api import SyntheticsApi

def k8_cluster(local_base_repo, k8_repo, destroy):
    '''create k8 cluster, kill cluster'''
    repo_dir = local_base_repo + k8_repo
    terraform = Terraform(working_dir=repo_dir)

    if destroy == 'true':
        terraform.apply(skip_plan=True, destroy=True)
    else:
        git_base_repo = 'https://github.com/jaycdave88/Azure_Terraform.git'
        tfvars = 'terraform.tfvars'

        #make sure repo is fresh
        path_exist = os.path.exists(local_base_repo)
        if path_exist is not True:
            git.Repo.clone_from(git_base_repo, local_base_repo)

        #vars needed to create cluster
        tfvars_path = """terraform.tfvars"""
        if os.path.exists(tfvars_path):
            dst = local_base_repo + k8_repo + tfvars
            shutil.copyfile(tfvars_path, dst)

        #create cluster
        #TODO how to manage error exceptions better
        terraform.init(upgrade=True)
        terraform.apply(skip_plan=True)

def get_state_info(local_base_repo, k8_repo):
    '''get state info'''

    state_file = local_base_repo + k8_repo + 'terraform.tfstate'
    access_mode = 'r'
    with open(state_file, access_mode, encoding='ascii') as file_object:
        tfstate = json.load(file_object)
    file_object.close()

    return tfstate

def send_log(message):
    '''send log to datadog'''

    hostname = socket.gethostname()
    service = get_service()

    body = [{
                "ddsource": "integration_testing",
                "ddtags": "env:test,version:1.0",
                "hostname": hostname,
                "message": message,
                "service": service
            }]
    configuration = Configuration()
    with ApiClient(configuration) as api_client:
        api_instance = LogsApi(api_client)
        api_instance.submit_log(body=body)

def check_for_errors(namespace, label_selector):
    '''check if containers are running'''

    kubectl_client = client.CoreV1Api()
    pod_json = kubectl_client.list_namespaced_pod(namespace=namespace, \
                                label_selector=label_selector)

    reason = 'ContainerCreating'
    containers_running = None
    while (reason == 'ContainerCreating') and (containers_running is None):
        #reset for more than one attempt
        containers_running = 'true'

        #cycle through containers
        for container_json in pod_json.items:

            containers_in_pod = len(container_json.status.container_statuses)

            for container in range(0, containers_in_pod):
                containers_running = \
                    container_json.status.container_statuses[container].state.running

                #see if any are not running
                if containers_running is None:
                    #if not, fail it get new status to try again
                    containers_running = None
                    pod_json = \
                        kubectl_client.list_namespaced_pod(namespace=namespace, \
                                            label_selector=label_selector)
                    container_name = \
                        container_json.status.container_statuses[container].name
                    reason = \
                        container_json.status.container_statuses[container].state.waiting.reason
                    error_message = \
                        container_json.status.container_statuses[container].state.waiting.message
                    break

    if containers_running == 'false':
        #if containercreating still
        if error_message is not None:
            message = "Error in integration test. Container: " + \
                container_name + " Reason: " + reason + " " + error_message
        else:
            message = "Error in integration test. Container: " + \
                      container_name + " Reason: " + reason
        send_log(message)

    return containers_running

def get_service():
    '''get service'''
    service = 'app_java'
    return service

def get_credentials(local_base_repo, k8_repo):
    '''get kubeconfig'''
    tfstate = get_state_info(local_base_repo, k8_repo)

    # get resources group
    resource_group = \
        tfstate["resources"][0]["instances"][0] \
            ["attributes"]["resource_group_name"]

    # get cluster name
    cluster_name = tfstate["resources"][0]["instances"][0]["attributes"]["name"]

    # get kubeconfig
    fq_config_path = "./.config"
    get_credentials_string = "az aks get-credentials --overwrite-existing " + \
                             "--only-show-errors -f " + fq_config_path + " --resource-group " \
                             + resource_group + " --name " + cluster_name + " > /dev/null"
    os.system(get_credentials_string)

    return fq_config_path

def deploy_k8_object(k8s_api_client, manifest):
    '''deploy k8 object via yaml'''
    json = None

    try:
        json = utils.create_from_yaml(k8s_api_client, manifest)
    except utils.FailToCreateError as error:
        send_log(f"Exception when applying yaml: {error}\n")

def create_k8_secret(name, data, secret_data):
    '''create k8 secret'''
    secret = client.V1Secret(
        api_version="v1",
        kind="Secret",
        metadata=client.V1ObjectMeta(name=name),
        data=data,
        string_data=secret_data
    )

    try:
        client_api
    except NameError:
        client_api = client.CoreV1Api()
    try:
        client_api.create_namespaced_secret(namespace="default",
                                            body=secret)
    except client.exceptions.ApiException as exception:
        send_log(f"Exception when creating secret: {exception}\n")

def get_load_balancer_ip(k8s_api_client):
    '''get lb ip'''
    service_name = "app-java"
    namespace = "default"

    kubectl_client = client.CoreV1Api(k8s_api_client)
    service_data = kubectl_client.read_namespaced_service(name=service_name,
                                                          namespace=namespace)

    while service_data.status.load_balancer.ingress is None:
        service_data = kubectl_client.read_namespaced_service(name=service_name,
                                                          namespace=namespace)
    lb_ip = service_data.status.load_balancer.ingress[0].ip

    return lb_ip

def datadog_browser_test(lb_ip):
    '''execute dd browser test'''
    #update load balancer ip, set dd test id
    start_url = f"http://{lb_ip}:8080/app-java-0.0.1-SNAPSHOT/"
    public_id = '476-sd6-bh6'

    body = {"tests": [{
                "public_id": public_id,
                "startUrl": start_url
    }]}

    #kick off test
    configuration = Configuration()
    with ApiClient(configuration) as api_client:
        api_instance = SyntheticsApi(api_client)
        trigger_data = api_instance.trigger_ci_tests(body=body)

    has_items = trigger_data.results
    test_passed = True

    #if there are results poll until get them
    if has_items is not False:
        #get result
        not_found_exception = True
        while not_found_exception is True:
            try:
                return_data = api_instance.get_browser_test_result(
                    public_id = public_id,
                    result_id = trigger_data.results[0].result_id
                )

                test_passed = return_data.result.passed
                not_found_exception = False
            except NotFoundException:
                not_found_exception = True

    if test_passed is False:
        send_log(message=f"""Test run failed, code: \
{return_data.result.failure.code}, message: \
{return_data.result.failure.message}""")

    return test_passed

def configure_load_balancer_for_traffic(service_manifest):
    '''configures the loadBalancerSourceRanges in the service to allow
    the access from the host we are on and dd synthetics hosts
    parameter service_manifest - path to the k8 svc manifest'''

    #get ip of host
    external_ip = requests.get('https://checkip.amazonaws.com').text.strip()

    #make sure don't add source ips more than once

    #get synthetic source ips if not there
    cmd = f"grep {external_ip} {service_manifest}"
    added = os.popen(cmd).read()
    if not added:
        with urllib.request.urlopen('https://ip-ranges.datadoghq.com/') as url:
            dd_ip_ranges = json.load(url)
        with open(service_manifest, "a", encoding='ascii') as file_pointer:
            file_pointer.write(f"  loadBalancerSourceRanges:\n    - {external_ip}/32")
            for ip_address in range(len(dd_ip_ranges["synthetics"]["prefixes_ipv4"])):
                file_pointer.write(f"""
    - {dd_ip_ranges["synthetics"]["prefixes_ipv4"][ip_address]}""")
            file_pointer.close()
