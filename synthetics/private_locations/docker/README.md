Private Locations with Docker
--

Add a Private Location
--

* In the Datadog UI, go to
[UX Monitoring -> Settings](https://app.datadoghq.com/synthetics/settings/private-locations)  

* Create a private location with the required fields  

* Add your proxy if required  

* Run the bash script on your host where you will run your docker container  

* Click 'View Installation Instructions'  

* Run the docker command from the UI from your shell  

* Test the URL  

* Setup a [new test](https://app.datadoghq.com/synthetics/tests)
using your location  

* Run your container in detached mode  

```  
docker run -d -v $PWD/<your_config>.json:/etc/datadog/synthetics-check-runner.json datadog/synthetics-private-location-worker  
```  

For advanced options use:  

```  
docker run --rm datadog/synthetics-private-location-worker --help  
```  
