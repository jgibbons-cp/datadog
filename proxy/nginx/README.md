NGINX Tracing - Open Source
--

This is taken from the Datadog documents site
[here](https://docs.datadoghq.com/tracing/setup_overview/proxy_setup/?tab=nginx#nginx-open-source).  

This was tested on EC2 running Ubuntu 22.04 LTS with nginx version 1.18.0.  

Configuration
--

1) [Install](https://app.datadoghq.com/account/settings#agent) the Datadog agent
 on the host.

2) Install the plugins (NOTE, they need to match the nginx version and
  opentracing versions)  
  - ```wget https://github.com/opentracing-contrib/nginx-opentracing/releases/download/v0.24.0/linux-amd64-nginx-1.18.0-ngx_http_module.so.tgz```  
  - Unarchive it and move it  
  ```
  sudo mv ngx_http_opentracing_module.so /usr/lib/nginx/modules/  
  ```

  - For this version of nginx use release
  [1.2.1](https://github.com/DataDog/dd-opentracing-cpp/releases/tag/v1.2.1)
  pulling down the library from
  [here](https://github.com/DataDog/dd-opentracing-cpp/releases/download/v1.2.1/libdd_opentracing.so)
  using wget and move it to the right directory
  ```
  sudo mv libdd_opentracing.so /usr/local/lib/libdd_opentracing_plugin.so
  ```

3) Export your tracing variables ```export DD_AGENT_HOST=localhost;
export DD_ENV=[tag value];```

4) Configure nginx.conf from ```/etc/nginx/nginx.conf```  Sample provided above.
  - See sections  
    - #datadog tracing env vars  
    - #load open tracing module  
    - #datadog config  

5) Configure your site, here called custom_server.conf at ```/etc/nginx/sites-enabled/[name].conf```  
  - See section  
    - #datadog tracing  

6) Create/configure ```/etc/nginx/dd-config.json``` by adding the tag and
updating the service name if desired.  

7) Restart nginx  
