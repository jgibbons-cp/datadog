Squid Proxy with Datadog - all examples from 20.04.1-Ubuntu
--  

* [Squid](https://github.com/yafernandes/datadog-experience/tree/main/labs/squid)
 - another example, but will go into a bit more detail here  

Proxy Setup
--
```  
sudo apt-get update  
sudo apt-get install squid  
```  

Update the conf in ```/etc/squid/squid.conf``` to the below  
```  
#can change to another port here if you want  
http_port 0.0.0.0:3128  

#for local monitoring of squid  
acl local src 127.0.0.1/32  

#allow datadog domains  
acl Datadog dstdomain .datadoghq.com  
acl Datadog dstdomain .datadoghq.eu  
acl Datadog dstdomain apt.datadoghq.com  
acl Datadog dstdomain keys.datadoghq.com  
#allow s3  
acl AWS dstdomain s3.amazonaws.com  

#allow domains hit by apt  
acl Ubuntu dstdomain us-west-2.ec2.archive.ubuntu.com  
acl Ubuntu dstdomain security.ubuntu.com  

http_access allow Datadog  
http_access allow local manager  
http_access allow AWS  
http_access allow Ubuntu  
```  

Restart squid  
```  
sudo service squid restart  
```  

Agent Setup
--

We will use a step by step install of an agent via the proxy.  By default, Squid
uses port 3128  

1) Prior to installing the agent we will need to set the proxy in the shell:  
```  
export https_proxy=http://<proxy>:3128 && export http_proxy=http://<proxy>:3128  
```  

2) Configure apt to use the proxy:  
```  
sudo vi /etc/apt/apt.conf.d/proxy.conf  
```  

Add the following to proxy.conf  
```  
Acquire::http::Proxy "http://<proxy>:3128";  
Acquire::https::Proxy "http://<proxy>:3128";  
```  

3) Install the agent using the step by step instructions from the bottom link
[here](https://app.datadoghq.com/account/settings#agent/ubuntu) next to
"If you prefer to see the installation step-by-step"  NOTE: <api_key> needs to be
updated with your key, but will be in the documents already if using these
instructions.  
```  
sudo apt-get update  
sudo apt-get install -y apt-transport-https curl gnupg  
sudo sh -c "echo 'deb [signed-by=/usr/share/keyrings/datadog-archive-keyring.gpg] https://apt.datadoghq.com/ stable 7' > /etc/apt/sources.list.d/datadog.list"  
sudo touch /usr/share/keyrings/datadog-archive-keyring.gpg  
sudo chmod a+r /usr/share/keyrings/datadog-archive-keyring.gpg  
curl https://keys.datadoghq.com/DATADOG_APT_KEY_CURRENT.public | sudo gpg --no-default-keyring --keyring /usr/share/keyrings/datadog-archive-keyring.gpg --import --batch  
curl https://keys.datadoghq.com/DATADOG_APT_KEY_382E94DE.public | sudo gpg --no-default-keyring --keyring /usr/share/keyrings/datadog-archive-keyring.gpg --import --batch  
curl https://keys.datadoghq.com/DATADOG_APT_KEY_F14F620E.public | sudo gpg --no-default-keyring --keyring /usr/share/keyrings/datadog-archive-keyring.gpg --import --batch  
sudo apt-get update  
sudo apt-get install datadog-agent datadog-signing-keys  
sudo sh -c "sed 's/api_key:.*/api_key: <api_key>/' /etc/datadog-agent/datadog.yaml.example > /etc/datadog-agent/datadog.yaml"  
sudo sh -c "sed -i 's/# site:.*/site: datadoghq.com/' /etc/datadog-agent/datadog.yaml"  
sudo sh -c "chown dd-agent:dd-agent /etc/datadog-agent/datadog.yaml && chmod 640 /etc/datadog-agent/datadog.yaml"  
```  

Configure processes and turn on logs:  
```  
sudo vi /etc/datadog-agent/datadog.yaml  
```  

Change  
```  
# logs_enabled: false  
```  
to  
```  
logs_enabled: true  
```  

Uncomment  
```  
# process_config:  
```  

and change   
```  
# enabled: "true"  
```  

to    
```  
enabled: "true"  
```  

Change  
```  
# proxy:    
#   https: http://<USERNAME>:<PASSWORD>@<PROXY_SERVER_FOR_HTTPS>:<PORT>  
#   http: http://<USERNAME>:<PASSWORD>@<PROXY_SERVER_FOR_HTTP>:<PORT>  
```  

to    
```  
proxy:    
  https: http://<USERNAME>:<PASSWORD>@<PROXY_SERVER_FOR_HTTPS>:<PORT>  
  http: http://<USERNAME>:<PASSWORD>@<PROXY_SERVER_FOR_HTTP>:<PORT>  
```  

and start the agent  
```  
sudo systemctl restart datadog-agent.service  
```  

Have fun!
