'''
k8 cicd functions
'''
import json
import os
import shutil
import socket
import sys
import urllib.request
import requests

import git
from kubernetes import client, utils, watch
from python_terraform import Terraform
from datadog_api_client.exceptions import NotFoundException
from datadog_api_client import ApiClient, Configuration
from datadog_api_client.v2.api.logs_api import LogsApi
from datadog_api_client.v1.api.synthetics_api import SyntheticsApi

def k8_cluster(local_base_repo, k8_repo, destroy):
    '''
    create k8 cluster, kill cluster
    local_base_repo (string) - base repo
    k8_repo (string) - terraform repo inside base repo
    destroy (string) - flag to destroy cluster
    '''
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
    '''
    get terraform state info
    local_base_repo (string) - base repo
    k8_repo (string) - terraform repo inside base repo
    '''

    state_file = local_base_repo + k8_repo + 'terraform.tfstate'
    access_mode = 'r'
    with open(state_file, access_mode, encoding='ascii') as file_object:
        tfstate = json.load(file_object)
    file_object.close()

    return tfstate

def send_log(message, service):
    '''
       Send log to datadog
       Parameter 1 (string): message to send to logs
       Parameter 2 (string): service (in Datadog terms) being tested
    '''

    hostname = socket.gethostname()

    body = [{
                "ddsource": "integration_testing",
                "ddtags": "env:dev",
                "hostname": hostname,
                "message": message,
                "service": service
            }]
    configuration = Configuration()
    with ApiClient(configuration) as api_client:
        api_instance = LogsApi(api_client)
        api_instance.submit_log(body=body)


def get_credentials(local_base_repo, k8_repo):
    '''
    get kubeconfig
    local_base_repo (string) - base repo
    k8_repo (string) - terraform repo inside base repo
    '''
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


def deploy_k8_object(k8s_api_client, manifest, service):
    '''
        Deploy k8 object via yaml
        k8s_api_client - api client object
        manifest - yaml manifest, only tested with deployments/services atm
        service (string) - dd service name
    '''
    json = None

    try:
        json = utils.create_from_yaml(k8s_api_client, manifest)
    except utils.FailToCreateError as error:
        send_log(f"Exception when applying yaml: {error}\n", service)


def create_k8_secret(name, data, secret_data):
    '''
    create k8 secret
    name (string) - name of secret
    data - {}
    secret_data (kv pairs) - secret data
    '''
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
        send_log(f"Error Exception when creating secret: {exception}\n", name)


def get_load_balancer_ip(k8s_api_client):
    '''
    get lb ip
    k8s_api_client - client object
    '''
    #TODO update when move to pre-prod testing
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


# TODO need to get rid of hard-coded test id and url
def datadog_browser_test(lb_ip):
    '''
    execute dd browser test
    lb_ip (string) - ip address of load balancer
    '''
    #update load balancer ip, set dd test id
    #TODO - make it generic when move to pre-prod
    start_url = f"http://{lb_ip}:8080/app-java-0.0.1-SNAPSHOT/"
    public_id = ''

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
        service = "add_service_here"
        message = f"""Test run failed, code:
 {return_data.result.failure.code}, message:
 {return_data.result.failure.message}"""
        send_log(message, service)

    return test_passed


def configure_load_balancer_for_traffic(service_manifest):
    '''
    configures the loadBalancerSourceRanges in the service to allow
    the access from the host we are on and dd synthetics hosts
    parameter service_manifest - path to the k8 svc manifest
    '''

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


def wait_for_running_pods(namespace, label_selector, service):
    '''
       Wait for pods to deploy or error
       Parameter 1: pod namespace
       Parameter 2: pod label selector
       Parameter 3: Datadog service tag
    '''
    watcher = watch.Watch()
    core_v1 = client.CoreV1Api()
    for event in watcher.stream(func=core_v1.list_namespaced_pod,
                          namespace=namespace,
                          label_selector=label_selector,
                          timeout_seconds=90):
        container_statuses = event["object"].status.container_statuses

        if event["object"].status.phase == "Running":
            watcher.stop()
        elif event["object"].status.phase == "Pending":
            try:
                for container_status in container_statuses:
                    if container_status.state.waiting.message is None:
                        pass
                    else:
                        send_log(f"""ERROR Run failed: \
{container_status.state.waiting.message}""", label_selector)
                        watcher.stop()
                        sys.exit(1)
            except TypeError:
                continue


def get_browser_test_result(public_id):
    '''
       Get the result of the Datadog browser test
       Parameter 1: test public id
    '''
    configuration = Configuration()
    with ApiClient(configuration) as api_client:
        api_instance = SyntheticsApi(api_client)
        response = api_instance.get_browser_test_latest_results(
            public_id = public_id
        )

    return response
