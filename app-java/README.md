End-to-End Monitoring with Java and Datadog
--

1. Pre-Requisites

- RUM is setup in [Datadog](https://docs.datadoghq.com/real_user_monitoring/browser/)
 This uses CDN Async  
- Install mvn from [here](https://gist.github.com/sebsto/19b99f1fa1f32cae5d00)
This will install mvn and multiple versions of Java.  By default it will use Java  
1.7.  We don't want this profiling and version in general so switch to Java 11:  
  - 'sudo update-alternatives --config java' and choose Java 11  
- Install docker  
  - 'sudo yum -y install docker'  
  - 'sudo usermod -aG docker $USER'  
  - exit the shell to complete  
  - start the service 'sudo service docker start'  

2. Deploy  

- Export your [API key](https://app.datadoghq.com/account/settings#api)  
 'export DD_API_KEY=<API_KEY>'  
- 'cd datadog/app-java/docker/'  
- Build the app  
  - 'sh build.sh'  
- Deploy the Datadog agent 'sh deploy_dd_docker_agent.sh'  
- Deploy mysql 'sh deploy_mysql.sh'  
- Deploy the app 'sh deploy_app_java.sh'  
- Navigate to the app: 'http://<host>:8080/app-java-0.0.1-SNAPSHOT/'

3. Full Stack Monitoring  

- RUM
- Front-End linked to back-end APM trace
