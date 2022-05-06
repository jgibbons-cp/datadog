Monitor Docker with Host Agent Rather than Docker Agent
--

This documentation is derived from
[here](https://github.com/DataDog/integrations-core/tree/master/docker_daemon#host-installation).  

Ubuntu
--

1) [Install](https://app.datadoghq.com/account/settings#agent)
the agent on the host.  

2) [Enable](https://app.datadoghq.com/account/settings#integrations/docker)
the Docker integration via the tile in the Datadog UI.  

3) Add the Agent user to the Docker group: ```sudo usermod -a -G docker dd-agent```  

4) Update the Docker conf file
```
sudo cp /etc/datadog-agent/conf.d/docker.d/conf.yaml.default /etc/datadog-agent/conf.d/docker.d/conf.yaml
```    

5) Restart agent ```sudo service datadog-agent restart```  

CentOS 7
--

1) [Install](https://app.datadoghq.com/account/settings#agent)
the agent on the host.  

2) [Enable](https://app.datadoghq.com/account/settings#integrations/docker)
the Docker integration via the tile in the Datadog UI.  

3) In CentOS 7, there is no docker group but rather just a dockerroot  

4) Perform the
[post-install](https://docs.docker.com/engine/install/linux-postinstall/)
Docker setup  
  - ```sudo groupadd docker```  
  - Add the non-root user to the group ```sudo usermod -aG docker $USER```  
  - Force changes ```newgrp docker```  
  - Verify you can run docker commands without sudo e.g. ```docker run hello-world```  

5) Follow the instructions in the integration
[tile](https://app.datadoghq.com/account/settings#integrations/docker) to
configure the integration.  
  - Add the Datadog user to the docker group ```sudo usermod -a -G docker dd-agent```  

6) Create the integration config:  
  - ```sudo vi /etc/datadog-agent/conf.d/docker.d/docker_daemon.yaml```  
  - Add the following to the file:  
```  
init_config:  

instances:  
  - url: "unix://var/run/docker.sock"  
    new_tag_names: true  
```  

7) Copy the Datadog docker example config to the config:  
  - ```sudo cp /etc/datadog-agent/conf.d/docker.d/conf.yaml.default /etc/datadog-agent/conf.d/docker.d/conf.yaml```

8) Restart the agent  

9) The check should give you no errors:  
  - ```sudo datadog-agent check docker```

10) Lauch a container if there are none running and you should see them in the
[container map](https://app.datadoghq.com/infrastructure/map?fillby=avg%3Aprocess.stat.container.io.wbps&node_type=container)
and the [live container view](https://app.datadoghq.com/containers)  
