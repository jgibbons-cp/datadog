Send Datadog Alerts to WebEx Teams
--

One of the ways that Datadog offers value is with over 400 out-of-the-box integrations.  Some of these are collaboration / notification integrations.  While Datadog currently does not offer a Webex Teams integration, there is a [webhook integration](https://docs.datadoghq.com/integrations/webhooks/) that can be used to send notifications to a room provided the Webex account is backed by Cisco Webex Common Identity (CI).  The webhook can be used in a Datadog [monitor](https://docs.datadoghq.com/monitors/monitor_types/) to send an [alert](https://docs.datadoghq.com/monitors/) to the room using the webhook with @ notation in the same way as you would an email notification.  

Steps to set up:  

1) NOTE: as far as I can tell, the Webex account must be backed by Cisco Webex Common Identity (CI) to use the REST API.  

2) From this [documentation](https://webexteamssdk.readthedocs.io/en/latest/user/quickstart.html) I was able to get my personal access token.  This is a developer token so you will likely need to get one from your admin.  I followed this:  

3) Get your Webex Teams Access Token*  

To interact with the Webex Teams APIs, you must have a Webex Teams Access Token. A Webex Teams Access Token is how the Webex Teams APIs validate access and identify the requesting user.  

To get your personal access token:  

* Login to the [developer portal](developer.webex.com)  
* Click on Docs or browse to the [Getting Started](https://developer.webex.com/getting-started.html) page  
* You will find your personal access token in the [Authentication](https://developer.webex.com/getting-started.html#authentication) section  

4) Set your bearer token like such in a terminal:  

export WEBEX_TEAMS_ACCESS_TOKEN=<token>  

You will lose this when you exit the shell unless you put it in your profile and log out and back into the shell.  

5) Using the [Webex REST API](https://developer.webex.com/docs/api/getting-started) you will need to get the room ID.  

You can use the Python SDK or curl.  I would recommend using curl as it is more similar to the webhook format.  

To get the room:  

curl -H "Authorization: Bearer $WEBEX_TEAMS_ACCESS_TOKEN" https://webexapis.com/v1/rooms  

Sample response snippet:  

{
         "id":"obfuscated",
         "title":"Example Group + Datadog Room",
         "type":"group",
         "isLocked":false,
         "lastActivity":"2020-07-02T18:35:43.224Z",
         "creatorId":"obfuscated",
         "created":"2020-06-16T18:04:52.909Z",
         "ownerId":"obfuscated"
      },

4) Setup the Datadog [webhook](https://app.datadoghq.com/account/settings#integrations/webhooks) and
[monitor](https://app.datadoghq.com/monitors#/create).
