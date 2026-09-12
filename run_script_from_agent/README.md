# Private Action Runner - Run a Script from the Datadog Agent

This document will guide you through an example of setting up a private action runner in the Datadog agent as well as running a predefined script.  

## Private Action Runner

[Setup](https://docs.datadoghq.com/actions/private_actions/set_up_agent_based/?tab=linux#manual-installation)

1) [Install](https://docs.datadoghq.com/actions/private_actions/set_up_agent_based/?tab=linux#install-the-runner) the runner on your choice of infrastructure.  In this example we will use an Ubuntu VM and the Datadog agent.  
  
2) Using [fleet automation](https://docs.datadoghq.com/actions/private_actions/set_up_agent_based/?tab=linux#using-fleet-automation-recommended) is the recommended way to install the agent with the correct configuration.  
  
  - In additional configuration in the UI choose "Enable agent to take action."  
  - Choose an API key then copy the instruction and install the agent.  
  
  - NOTE: if this is an existing agent you can add it to `/etc/datadog-agent/datadog.yaml` then restart the agent.  The `actions_allowlist` can't be added in fleet view so it must be done here.

    The yaml to add is:

    ```
    private_action_runner:
      enabled: true
      actions_allowlist:
        - com.datadoghq.script.runPredefinedScript
    ```
  
3) [Confirm](https://app.datadoghq.com/actions/private-action-runners) your private action runner is available.  
  
## Run a Script with the Runner

The documentation is [here](https://docs.datadoghq.com/actions/private_actions/run_script/?tab=linux).  We are using an [agent-based runner](https://docs.datadoghq.com/actions/private_actions/run_script/?tab=linux#prerequisites).  We have already added `com.datadoghq.script.runPredefinedScript`.  
  
## Configure the Script to Run

The script will live in `/etc/datadog-agent/private-action-runner/script-config.yaml`.  An example can be found [here](https://docs.datadoghq.com/actions/private_actions/run_script/?tab=linux#configure-scripts).  
  
##Permissions

The script will be run by a non-root user called dd-agent.  If you need to run privileged commands you will need to [grant permissions](https://docs.datadoghq.com/actions/private_actions/run_script/?tab=linux#grant-permissions).  Narrow them down as granular as possible.  

## Testing

The execution of the script can be tested using a [workflow](https://docs.datadoghq.com/actions/workflows/).  To trigger it choose a [monitor trigger](https://docs.datadoghq.com/actions/workflows/trigger/).  The action will be `Run Predefined Script` and you can test it before calling it from an actual monitor.  

## Example


