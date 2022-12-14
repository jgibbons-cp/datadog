'''create k8 cluster, test agents, deploy and test app containers, app, kill cluster'''
from cicd_functions import *
from kubernetes import config

def main():
    '''main'''
    os.getenv('DD_API_KEY')
    destroy = 'false'
    #TODO add this as a command line flag so easy to configure CI
    #decreasing ci without pushed changes
    pre_push_test = False

    local_base_repo = './Azure_Terraform/'
    k8_repo = 'k8/'

    k8_cluster(local_base_repo, k8_repo, destroy)

    fq_config_path = get_credentials(local_base_repo, k8_repo)

    git_base_repo = "https://github.com/jgibbons-cp/datadog.git"
    local_base_repo = "datadog"
    path_to_deployment = '/app-java/kubernetes/app-java.yaml'
    path_to_service = '/app-java/kubernetes/app_java_service.yaml'

    #make sure the repo is fresh if not pre-push test
    path_exist = os.path.exists(local_base_repo)
    if path_exist is True and pre_push_test is False:
        shutil.rmtree(local_base_repo)

    if pre_push_test is False:
        git.Repo.clone_from(git_base_repo, local_base_repo)

    #load config
    config.load_kube_config(config_file=fq_config_path)

    #get datadog agent pods
    namespace = 'default'
    label_selector = 'app.kubernetes.io/component=agent'

    containers_running = None
    #any errors in any containers in pods
    containers_running = check_for_errors(namespace, label_selector)

    if containers_running != 'false':
        namespace = 'default'
        label_selector = 'app.kubernetes.io/component=cluster-agent'

        #any errors in any containers in pods
        containers_running = check_for_errors(namespace, label_selector)

    #create secret for app-java rum
    secret_data = {
        'APPLICATION_ID': os.getenv('APPLICATION_ID'),
        'CLIENT_TOKEN': os.getenv('CLIENT_TOKEN')
    }
    create_k8_secret("dd-rum-tokens", {}, secret_data)

    if containers_running != 'false':
        namespace = 'default'
        label_selector = 'run=app-java'

        #deploy
        manifest = local_base_repo + path_to_deployment
        k8s_api_client = client.ApiClient()
        deploy_k8_object(k8s_api_client, manifest)

        #any errors in any containers in pods
        containers_running = check_for_errors(namespace, label_selector)

        service_manifest = local_base_repo + path_to_service

        configure_load_balancer_for_traffic(service_manifest)

        #deploy service
        deploy_k8_object(k8s_api_client, service_manifest)

        lb_ip = get_load_balancer_ip(k8s_api_client)

    if containers_running != 'false':
        namespace = 'default'
        label_selector = 'run=mysql'

        # deploy
        path_to_deployment = '/app-java/kubernetes/mysql_ja.yaml'
        manifest = local_base_repo + path_to_deployment
        deploy_k8_object(k8s_api_client, manifest)

        # any errors in any containers in pods
        containers_running = check_for_errors(namespace, label_selector)

    browser_test_result = datadog_browser_test(lb_ip)

    if (containers_running != 'false') and browser_test_result is True:
        message = "Successful run of integration test for " + get_service()
        send_log(message)

    destroy = 'true'
    local_base_repo = './Azure_Terraform/'
    #k8_cluster(local_base_repo, k8_repo, destroy)

if __name__ == "__main__":
    main()
