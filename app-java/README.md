End-to-End Monitoring with Java and Datadog
--

1. Pre-Requisites

- Instructions for Ubuntu  
- RUM is setup in [Datadog](https://docs.datadoghq.com/real_user_monitoring/browser/)
 This uses CDN Async  
- Update packages ```sudo apt-get update```  
- Install the default JRE - ```sudo apt install -y default-jre```  
- Install mvn - ```sudo apt install -y maven```  
- Install docker (we will use docker for the db even if tomcat is running on vm)  
  - ```  
       sudo install -m 0755 -d /etc/apt/keyrings  
       curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg  
       sudo chmod a+r /etc/apt/keyrings/docker.gpg  
  
       sudo apt-get update  
       echo \  
       "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \  
       "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \  
       sudo tee /etc/apt/sources.list.d/docker.list > /dev/null  
         
       sudo apt-get update  
       sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin  
       sudo usermod -aG docker $USER  
  
       #reboot host so don't have to run docker as room  
       sudo reboot    
    ```  
- Decide whether you are going to use log4j2 or logback for logs and traceID
injection  
  - The dependencies for both are in pom.xml  
  - In QueryEmployees.java it defaults to log4j2. If you want to use logback
then comment out the log4j2 imports and Logger declaration and uncomment those
for logback.  NOTE: if you change this you will need to use an image other than
the one in my registry.  
2. Deploy  

2a) Docker  
  
- Export your [API key](https://app.datadoghq.com/account/settings#api)  
 ```
 export DD_API_KEY=<API_KEY>
 ```  
- Export your
[RUM Client Token](https://app.datadoghq.com/rum/list?from_ts=1633643340056&to_ts=1633729740056&live=true)
in 'Edit Application' with ```export CLIENT_TOKEN=<CLIENT_TOKEN>```  
- Export your
[RUM Application ID](https://app.datadoghq.com/rum/list?from_ts=1633643340056&to_ts=1633729740056&live=true)
in 'Edit Application' with ```export APPLICATION_ID=<APPLICATION_ID>```  
- By default the application will use mysql with the sample employees database.
  You can use the environment variables DB_HOST and DB to switch to a different
  database host and db.  
- ```cd <path_to_repo>/datadog/app-java/docker/```  
- Build the app  
  - ```sh build.sh```  
- Deploy the Datadog agent ```sh deploy_dd_docker_agent.sh```  
- Deploy mysql ```sh deploy_mysql.sh```  
- Deploy the app ```sh deploy_app_java.sh```  

2b.  Local VM Tomcat with mysql in Docker  
  
- Install Tomcat ```sudo apt-get -y install tomcat9```    
- Build the war file (need to pull this repo to cd)  
  - ```    
       cd datadog/app-java  
       mvn clean && mvn compile && mvn package  
    ```  
- Deploy the war file to Tomcat ```sudo cp <path_to_repo>/datadog/app-java/target/app-java-0.0.1-SNAPSHOT.war /var/lib/tomcat9/webapps/```
- Ensure mysql is not running on the host ```sudo service mysql stop```  
- Deploy mysql ```docker run --detach --name=mysql-test --publish 3306:3306 jenksgibbons/mysql_ja```  
- Set the db host to localhost.  
  ```  
     echo "export DB_HOST=localhost" > setenv.sh  

     ## The next line is optional for Datadog trace library injection
     echo "export DD_CONFIG_SOURCES=BASIC" >> setenv.sh  

     sudo mv setenv.sh /usr/share/tomcat9/bin/setenv.sh       
  ```  
- Optional - for Java Host Trace Library injection  
  ```
     sudo apt-get install datadog-apm-inject datadog-apm-library-java
     dd-host-install  
  ```
     
- Restart tomcat ```sudo service tomcat9 restart```  
- Install the Datadog agent  
- Open up 8080 to your IP address  
- Navigate to the app: 'http://<host>:8080/app-java-0.0.1-SNAPSHOT/'

3. Full Stack Monitoring  

- RUM
- Front-End linked to back-end APM trace  

4. Integrations  

- mysql  
- jmx  
