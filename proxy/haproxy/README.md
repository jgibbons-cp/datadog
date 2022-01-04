HAProxy
--  

HAProxy can be used to proxy traffic to Datadog from a network that does not
have direct access to the Internet.  HAProxy documentation for Datadog located
[here](https://docs.datadoghq.com/agent/proxy/?tab=agentv6v7#haproxy)  

Setup Example (AWS)
--

* Install haproxy  
* Copy the haproxy Datadog configuration to the haproxy configuration directory:  
  ```/etc/haproxy```  
* Restart haproxy  
  ```sudo service haproxy restart```  
* Restrict traffic from the security group where the agents are located  

Agent Setup Example (AWS)
--

* Install the agent for your OS as documented
[here](https://app.datadoghq.com/account/settings#agent)  
* Replace the configuraton file with the stripped out datadog.yaml here.
  ```sudo cp repo_dir/datadog.yaml /etc/datadog-agent/```  
*  Replace <redacted> with your API key from the install step above  
*  Replace ip_of_proxy with the private IP or FQDN of the proxy  
*  Restart agent  
  ```sudo systemctl restart datadog-agent```  
* Allow outbound traffic to the security group of the proxy on TCP ports
3834-3839

Confirm in [Datadog](https://app.datadoghq.com/infrastructure) that the host is
reporting metrics.  

Have fun!  
