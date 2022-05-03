Monitor Docker with Host Agent Rather than Docker Agent
--

This documentation is derived from
[here](https://github.com/DataDog/integrations-core/tree/master/docker_daemon#host-installation).  

1) [Install](https://app.datadoghq.com/account/settings#agent)
the agent on the host.  

2) [Enable](https://app.datadoghq.com/account/settings#integrations/docker)
the Docker integration via the tile in the Datadog UI.  

3) Add the Agent user to the Docker group: ```sudo usermod -a -G docker dd-agent```  

4) Update the Docker conf file
```
sudo mv /etc/datadog-agent/conf.d/docker.d/conf.yaml.default /etc/datadog-agent/conf.d/docker.d/conf.yaml
```    

5) Restart agent ```sudo service datadog-agent restart```  
