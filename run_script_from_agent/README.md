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
  
## Permissions

The script will be run by a non-root user called dd-agent.  If you need to run privileged commands you will need to [grant permissions](https://docs.datadoghq.com/actions/private_actions/run_script/?tab=linux#grant-permissions).  Narrow them down as granular as possible.  

## Testing

The execution of the script can be tested using a [workflow](https://docs.datadoghq.com/actions/workflows/).  To trigger it choose a [monitor trigger](https://docs.datadoghq.com/actions/workflows/trigger/).  The action will be `Run Predefined Script` and you can test it before calling it from an actual monitor.  

## Example

In this example, the private action runner will kill all nginx processes.  
  
1) In an editor add the following to `/etc/datadog-agent/private-action-runner/script-config.yaml`.  
  
```
schemaId: script-credentials-v1
runPredefinedScript:
  clean_up_stale_processes:
    command: ["sudo", "/home/ubuntu/test_script.sh"]
```  
  
The restart the agent.  
  
```
sudo systemctl restart datadog-agent
```  
  
2) Grant permissions to the `dd-agent` user.  
  
Add the following to to the sudoers file using `visudo`.  
  
```
dd-agent ALL=(ALL) NOPASSWD: /home/ubuntu/test_script.sh
dd-agent ALL=(ALL) NOPASSWD: /usr/bin/killall nginx
```
  
3) Install nginx on the host and confirm it is running  
  
  ```
  sudo apt install nginx -y
  ps auxww | grep nginx
  ```
4) Create the script in `/home/ubuntu` and configure it  
  
a) 
```
#!/bin/bash
#
sudo /usr/bin/killall nginx
```

b) Make it executable  
  
```
chmod 755 /home/ubuntu/test_script.sh
```

c) Ensure the directory structure has execute on all directories  

```
chmod o+x /home/ubuntu 
```

5) Configure the test in Datadog  
  
a) Create a [workflow](https://app.datadoghq.com/workflow?my=false&sort=-favorite%2C-last_updated_at)

b) Choose a monitor for the trigger.  
  
c) At the bottom of the trigger in the UI choose the action: Script -> Run Predefined Script  
  
d) Click into the action and in `Inputs` choose `Connection` then your 'Private Action Runner Connection' from the dropdown.  
  
e) In 'Script Parameters' toggle the variable input on the right '{{' and add your script name: `clean_up_stale_processes`  
  
f) In the top right corner click `Run` then with `Manual` chosen click `Run` in the pop-up.  
  
6) Confirm the processes were killed  
  
```
$ ps auxww | grep nginx
ubuntu      6248  0.0  0.2   7084  2200 pts/0    S+   02:25   0:00 grep --color=auto nginx
```

Either publish the workflow or delete it.  


