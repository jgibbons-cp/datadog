'''
   Configure app and ensure dependencies are set
'''
import os
from os.path import exists
import shutil
import yaml

GLOBAL_CONFIG = "config.yaml"

def npm_installed():
    '''
       npm is needed, exit if not installed or available in path
    '''
    success = 0
    installed = os.system("npm -v 2&> /dev/null")
    error = ""

    if installed != success:
        error = "Error: npm is required for browser tests... Exiting..."

    return error


def import_cicd_functions():
    '''
       Copy the cicd_functions module to the local directory
    '''

    # get config
    with open(GLOBAL_CONFIG, 'r', encoding="ascii") as stream:
        config_data = yaml.safe_load(stream)

    local_module = config_data["modules"]["cicd"]
    if not exists(local_module):
        shutil.copyfile(config_data["modules"]["module_relative_path"],
                        local_module)


def create_test_id_config(test_public_id, config_file):
    '''
       Create the test id config for Datadog continuous testing
       Parameter 1: create_test_id_config - public id of Datadog browser test
       Parameter 2: config file for test id
    '''
    with open(config_file, "w", encoding="ascii") as file:
        file_json = f'{{"tests": [{{"id": \"{test_public_id}\"}}]}}'
        file.write(file_json)


def create_tunnel_config(start_url, config_file):
    '''
       Create the test tunnel config for Datadog continuous testing
       Parameter 1: start_url - url for tunnel
       Parameter 2: config_file - config file for tunnel
    '''
    with open(config_file, "w", encoding="ascii") as file:
        file_json = f'{{"global": {{"startUrl": \"{start_url}\"}}, "tunnel": true}}'
        file.write(file_json)


def configure_datadog_continuous_testing():
    '''
       Create and/or update Datadog continuous testing config files
    '''
    config_data = get_config()
    config_file = config_data["browser_test"]["id_config"]
    test_public_id = config_data["browser_test"]["public_id"]

    # test id config
    try:
        with open(config_file, 'r', encoding="ascii") as file:
            # read all content from a file using read()
            file_data = file.read()
            # check if string present or not
            if test_public_id not in file_data:
                create_test_id_config(test_public_id, config_file)
    except FileNotFoundError:
        create_test_id_config(test_public_id, config_file)

    # test tunnel config
    tunnel_config = config_data["browser_test"]["tunnel_config"]
    ip_address = "127.0.0.1"
    port = config_data["browser_test"]["tunnel_port"]
    start_url = f"http://{ip_address}:{port}"

    try:
        with open(tunnel_config, 'r', encoding="ascii") as file:
            # read all content from a file using read()
            file_data = file.read()
            # check if string present or not
            if start_url not in file_data:
                create_tunnel_config(start_url, tunnel_config)
    except FileNotFoundError:
        create_tunnel_config(start_url, tunnel_config)


def get_config():
    '''
       Get the application configuration
       return - configuration data
    '''
    # get config
    with open(GLOBAL_CONFIG, 'r', encoding="ascii") as stream:
        config_data = yaml.safe_load(stream)

    return config_data
