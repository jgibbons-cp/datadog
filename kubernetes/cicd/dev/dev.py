'''
    environment to test k8 infrastructure configuration changes in dev
'''
import os
import subprocess
from subprocess import Popen, PIPE
import sys
from os import O_NONBLOCK
from fcntl import fcntl, F_GETFL, F_SETFL
import time

import setup
# get module for import
setup.import_cicd_functions()
from local_cicd_functions import create_k8_secret, deploy_k8_object, \
    send_log, wait_for_running_pods, get_browser_test_result
from kubernetes import config, client


def is_supported_object(manifest):
    '''
       Only deployments are tested atm
       Parameter 1: manifest - k8 manifest
    '''
    with open(manifest, 'r', encoding='ascii') as file:
        # read all content from a file using read()
        kind_field = file.read()
        # check if string present or not
        if 'kind: Deployment' not in kind_field and 'kind: Service' not in kind_field:
            raise AttributeError(
                "Only K8 deployments/services have been tested... Exiting..."
            )


def delete_kind_cluster(kind_dir):
    '''
        Delete the local cluster
        Parameter 1: configuration data to get path to kind directory
    '''
    os.spawnlp(os.P_WAIT, "bash", "bash",
               f"{kind_dir}/delete_kind.sh")

def main():
    '''
       Create a kind cluster, deploy kubernetes objects, test deploy using
       datadog browser test
    '''
    # get configuration data
    config_data = setup.get_config()
    # get service being tested
    service = config_data["service"]["name"]

    # can't do this without npm
    error = setup.npm_installed()
    if error:
        send_log(error, service)
        sys.exit(1)

    # get working directory
    script_directory = os.getcwd()

    # move to kind directory, create cluster and set context
    # path of kind repo set in config
    proc_dir = os.getcwd()
    kind_dir = f'{proc_dir}/{config_data["kind"]["repo_path"]}'
    
    # create cluster and wait for it to come up or exit
    os.chdir(kind_dir)
    ret_val = os.spawnlp(os.P_WAIT, "bash", "bash", "create_kind.sh")
    if ret_val != 0:
        sys.exit(1)

    # load kubeconfig
    kubeconfig = config_data["kind"]["cluster_kubeconfig"]
    config.load_kube_config(config_file=kubeconfig)
    os.chdir(proc_dir)

    try:
        # iterate through all secrets for all applications
        iterator = 0
        while iterator < len(config_data["secret"]):
            # iterate through all key:values to be added to secret
            counter = 0
            # (secret kvs - name kv) / 2 to account for kv pairs
            kv_pairs = (len(config_data["secret"][iterator]["generic"])-1)/2

            secret_data = {}
            while counter < kv_pairs:
                secret_key = f"secret_key_{counter}"
                value = f"value_{counter}"

                secret_data[config_data
                    ["secret"][iterator]["generic"][secret_key]] = \
                    config_data["secret"][iterator]["generic"][value]

                # next kv
                counter += 1

            create_k8_secret(config_data["secret"][iterator]["generic"]["name"], {},
                             secret_data)
            # next secret
            iterator += 1
    except KeyError:
        pass

    k8s_api_client = client.ApiClient()

    # deploy k8 objects (e.g. deploy)
    iterator = 0
    ret_val = 0

    while iterator < len(config_data["application"]):
        # deploy manifest
        try:
            manifest = config_data["application"][iterator]["object"]["manifest"]
            deploy_k8_object(k8s_api_client, manifest, service)
        except AttributeError as error:
            # if error in manifest
            error = str(error)
            # log sent to datadog
            send_log(f"ERROR Object deployment failed: {error}", service)
            # delete cluster
            delete_kind_cluster(kind_dir)
            sys.exit(1)

        # wait for results
        namespace = config_data["application"][iterator]["object"]["namespace"]
        label_selector = config_data["application"][iterator]["object"]["label_selector"]
        ret_val = wait_for_running_pods(namespace, label_selector, service)
        if ret_val != 0:
            delete_kind_cluster(kind_dir)
            sys.exit(1)

        iterator += 1

    # methods attempted:
    # 1) os.popen - waits
    # 2) kubernetes python client port forward - waits
    # 3) spawnlp with --kubeconfig: error on flag? so passed via env var
    #os.environ["KUBECONFIG"] = f"{config_data['kind']['repo_path']}/{kubeconfig}"
    #os.getenv("KUBECONFIG")

    # command to forward port for test
    cmd = f'kubectl port-forward --kubeconfig {kind_dir}/{kubeconfig} {config_data["port_forward"]["type_name"]} \
{config_data["browser_test"]["tunnel_port"]}\
:{config_data["browser_test"]["app_port"]}'

    # pep8 with not used as waits
    kubectl_pid = Popen(cmd, shell=True, stdin=PIPE, stdout=PIPE, stderr=PIPE,
              universal_newlines=True, close_fds=True)
    # get and set non block flags
    flags = fcntl(kubectl_pid.stdout, F_GETFL)
    fcntl(kubectl_pid.stdout, F_SETFL, flags | O_NONBLOCK)
    flags = fcntl(kubectl_pid.stderr, F_GETFL)
    fcntl(kubectl_pid.stderr, F_SETFL, flags | O_NONBLOCK)
    time.sleep(5)

    try:
        output_stream = kubectl_pid.stdout.read()
        if not output_stream:
            output_stream = kubectl_pid.stderr.read()
            send_log(f"ERROR: {output_stream}", service)
            delete_kind_cluster(kind_dir)
            sys.exit(1)
    except TypeError:
        output_stream = kubectl_pid.stderr.read()
        send_log(f"ERROR: {output_stream}", service)
        delete_kind_cluster(kind_dir)
        sys.exit(1)

    # skip browser test
    if not config_data["browser_test"]["skip"]:
        # back to script directory
        os.chdir(script_directory)

        # create config files cicd.synthetics.json and datadog-ci.json
        # or update
        setup.configure_datadog_continuous_testing()
        
        try:
            # datadog browser test
            output = subprocess.check_output(["npm", "run", "datadog-ci-synthetics"])
            output = output.decode()
            output = output.split("=== REPORT ===\n", 1)[1]
            output = "".join(output)
            send_log(f"info {output}", service)
        except subprocess.CalledProcessError:
            result = get_browser_test_result(config_data["browser_test"]["public_id"])
            message = f"""ERROR {result["results"][0]["result"]["errorMessage"]} \
    Error occurred after step \
{result["results"][0]["result"]["step_count_completed"]} \
of {result["results"][0]["result"]["step_count_total"]} steps. Exiting..."""
            delete_kind_cluster(kind_dir)
            send_log(message, service)

        # clean up
        os.system(f"kill -9 {kubectl_pid.pid}")
    else:
        send_log("Success", service)
    delete_kind_cluster(kind_dir)

    cmd_output = ""
    os.system('git config --global user.email "jenks.gibbons@datadoghq.com"')
    os.system('git config --global user.name "Jenks"')
    os.system("git fetch --unshallow")
    try:
        cmd_output = subprocess.check_output("git checkout main && git merge --no-ff \
                                    --allow-unrelated-histories \
                                    origin/dev-app-java && git push", \
                                    shell=True, text=True)
        cmd_output = f"INFO {return_string}"
    except CalledProcessError as error:
        cmd_output = str(error)
        cmd_output = f"ERROR {return_string}"

    send_log(cmd_output, service)
    
    local_module = config_data["modules"]["cicd"]
    os.remove(f"{script_directory}/{local_module}")


if __name__ == "__main__":
    main()
