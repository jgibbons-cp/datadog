# Private Action Runner - Run a Script from the Datadog Agent

This document will guide you through an example of setting up a private action runner in the Datadog agent as well as running a predefined script.  

## Private Action Runner

### Setup

1) [Install](https://docs.datadoghq.com/actions/private_actions/set_up_agent_based/?tab=linux#install-the-runner) the runner on your choice of infrastructure.  In this example we will use an Ubuntu VM and the Datadog agent.  
  
2) Using [fleet automation](https://docs.datadoghq.com/actions/private_actions/set_up_agent_based/?tab=linux#using-fleet-automation-recommended) is the recommended way to install the agent with the correct configuration.  
  
  - In additional configuration in the UI choose "Enable agent to take action."  
  - Choose an API key then copy the command and install the agent.  
  
  - NOTE: if this is an existing agent you can add it to `/etc/datadog-agent/datadog.yaml` then restart the agent.  The `actions_allowlist` can't be added in fleet view so it must be done here.

    The yaml to add is:

    ```
    private_action_runner:
      enabled: true
      actions_allowlist:
        - com.datadoghq.script.runPredefinedScript
    ```
  
3) [Confirm](https://app.datadoghq.com/actions/private-action-runners) your private action runner is available.  Note, it may take a minute to connect so if it shows `INACTIVE` give it a minute.  
  
## Run a Script with the Runner

The documentation is [here](https://docs.datadoghq.com/actions/private_actions/run_script/?tab=linux).  We are using an [agent-based runner](https://docs.datadoghq.com/actions/private_actions/run_script/?tab=linux#prerequisites).  We have already added `com.datadoghq.script.runPredefinedScript`.  
  
## Configure the Script to Run

The script will live in `/etc/datadog-agent/private-action-runner/script-config.yaml`.  An example can be found [here](https://docs.datadoghq.com/actions/private_actions/run_script/?tab=linux#configure-scripts).  We will walk through a full example below.  
  
## Permissions

The script will be run by a non-root user called `dd-agent`.  If you need to run privileged commands you will need to [grant permissions](https://docs.datadoghq.com/actions/private_actions/run_script/?tab=linux#grant-permissions).  Narrow them down to be as granular as possible.  

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
  $ sudo apt install nginx -y
  $ ps auxww | grep nginx
  root        3149  0.0  0.7  11208  7076 ?        S    19:57   0:00 nginx: master process /usr/sbin/nginx -g daemon on; master_process on;
  www-data    3152  0.0  0.4  12896  4504 ?        S    19:57   0:00 nginx: worker process
  www-data    3153  0.0  0.4  12896  4444 ?        S    19:57   0:00 nginx: worker process
  ubuntu      3240  0.0  0.2   7084  2228 pts/0    S+   19:57   0:00 grep --color=auto nginx
  ```
4) Create the script `/home/ubuntu/test_script.sh` and configure it  
  
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
  
c) At the bottom of the trigger box in the UI choose the blue `+` then the action: `Script -> Run Predefined Script`  
  
d) In the action configuration in `Inputs`, choose `Connection` then your `Private Action Runner Connection` from the dropdown.  
  
e) In 'Script Parameters' toggle the variable input on the right '{{' and add your script name: `clean_up_stale_processes`.  Note, this is from the block that has the command in `/etc/datadog-agent/private-action-runner/script-config.yaml`  
  
f) In the top right corner click `Run` then with `Manual` chosen click `Run` in the pop-up.  
  
6) Confirm the processes were killed  
  
```
$ ps auxww | grep nginx
ubuntu      6248  0.0  0.2   7084  2200 pts/0    S+   02:25   0:00 grep --color=auto nginx
```

Either publish the workflow or delete it.  

## Connect to a Monitor

To automate the process in the event of some condition create a monitor.  For example, a [log monitor](https://app.datadoghq.com/monitors/create/log) can alert if a certain number of logs meets a condition (e.g. greater than x over n minutes),  

In the alert section you can use the monitor as a notification.  In my example, my workflow is called `Test Running a Script`.  Therefore, I can alert off of it using `@` notation in the notification section.  

```
{{#is_alert}}
Condition is met, alerting to workflow.
# NOTE, then name when choosing is 'Test Running a Script' but internally the workflow is referred to by a reference to owner and time.
@workflow-Jenks-Sep-12-2026-1259 
{{/is_alert}}
```

After you configure it, you can test the alert by clicking the `Test Notifications` button at the bottom.  

