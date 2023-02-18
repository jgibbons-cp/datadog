Datadog Node.js 18.x Instrumentation Examples
--

Here are several examples of how to [instrument](https://docs.datadoghq.com/serverless/installation/nodejs/?tab=custom) a Node.js example in Lambda with Datadog.  
  
NOTE: if you don't *need* to package the function yourself, the easiest path forward is example 2.  A Datadog wrapper in the function code is *only* required when packaging the function yourself on arm64.  
  
1) x86_64 - packaging the Lambda rather than using the Datadog pre-built layer.  I used the x86_64 here so there is no need to apply a Datadog wrapper in the function code.  This is *only* required when not using the pre-built layer and packaging yourself on arm.  

- Example function named *jenks-package-x86*  
- Inside an empty directory run  `npm install datadog-lambda-js dd-trace`  
  
  
- Create index.js with the [Monitor Custom Business Logic](https://docs.datadoghq.com/serverless/installation/nodejs/?tab=custom#monitor-custom-business-logic) code  
- run `npm install datadog-lambda-js dd-trace`  
- inside directory you will have: `index.js	node_modules package-lock.json package.json`  
- Package it `zip -r jenks-package-x86.zip .`  
- Upload the zipfile to the function  
- Add the layer for the x86_64 Datadog Lambda extension (edit region):  `arn:aws:lambda:us-west-2:464622532012:layer:Datadog-Extension:37`  
- In runtime settings for the function, change the handler to `node_modules/datadog-lambda-js/dist/handler.handler`  
- Add the following environment variables:  
```  
DD_LAMBDA_HANDLER=index.handler  
DD_API_KEY=<api_key> (testing, likely want to use a secret DD_API_KEY_SECRET_ARN)  
DD_SITE=datadoghq.com (for your site this is us1)  
```    
- Create a test for the function  
- Test it  
  
```  
{  
  "statusCode": 200,  
  "body": "\"Hello from serverless!\""  
}  
  
TELEMETRY	Name: datadog-agent	State: Subscribed	Types: [Platform, Function, Extension]  
EXTENSION	Name: datadog-agent	State: Ready	Events: [INVOKE,SHUTDOWN]  
START RequestId: 9f294aed-ba7e-49fe-a1b9-9a7ad6313712 Version: $LATEST  
2023-02-18T22:23:34.030Z	9f294aed-ba7e-49fe-a1b9-9a7ad6313712	INFO	[dd.trace_id=7064794513067584152 dd.span_id=3738137934146625350] Hello, World!  
END RequestId: 9f294aed-ba7e-49fe-a1b9-9a7ad6313712  
REPORT RequestId: 9f294aed-ba7e-49fe-a1b9-9a7ad6313712	Duration: 1745.59 ms	Billed Duration: 1746 ms	Memory Size: 128 MB	Max Memory Used: 127 MB	Init Duration: 733.21 ms  
```  
- Look at your telemetry in Datadog:  
* [Serverless](https://app.datadoghq.com/functions)  
* [Custom metric - coffee_house.order_value](https://app.datadoghq.com/metric/summary?filter=coff&metric=coffee_house.order_value)  
  
2) ARM using Datadog's Pre-Packaged Layer  
  
- Example function named _jenks-pre-built-layer-arm_ for arm64  
- Add code with the [Monitor Custom Business Logic](https://docs.datadoghq.com/serverless/installation/nodejs/?tab=custom#monitor-custom-business-logic) code to index.mjs in the function  
* I am no node expert so if you know how to do this differently please do and if you are up to it submit a PR  
* Change the following so require is not used:  
```  
//const { sendDistributionMetric, sendDistributionMetricWithDate } = require('datadog-lambda-js');  
import * as d from "datadog-lambda-js";  
```  
```  
//const tracer = require('dd-trace');  
import tracer from 'dd-trace';  
```  
```  
//exports.handler = async (event) => {  
export const handler = async (event) => {  
```  
```  
//sendDistributionMetric(  
d.sendDistributionMetric(  
```  

- Add the pre-built layer (editing region and runtime) `arn:aws:lambda:us-west-2:464622532012:layer:Datadog-Node18-x:86`  
- Add the Datadog Lambda Extension (editing region) `arn:aws:lambda:us-west-2:464622532012:layer:Datadog-Extension-ARM:37`  
- In runtime settings for the function, change the handler to `/opt/nodejs/node_modules/datadog-lambda-js/handler.handler`
- Add the following environment variables:  
```  
DD_LAMBDA_HANDLER=index.handler  
DD_API_KEY=<api_key>  (testing, likely want to use a secret DD_API_KEY_SECRET_ARN)  
DD_SITE=datadoghq.com (for your site this is us1)  
```  
- Deploy  
- Create a test for the function  
- Test it  
  
```  
Test Event Name  
test  
  
Response  
{  
  "statusCode": 200,  
  "body": "\"Hello from serverless!\""  
}  
  
Function Logs  
TELEMETRY	Name: datadog-agent	State: Subscribed	Types: [Platform, Function, Extension]  
EXTENSION	Name: datadog-agent	State: Ready	Events: [INVOKE,SHUTDOWN]  
START RequestId: df9ec639-e0a4-486d-a003-87ac82035858 Version: $LATEST  
2023-02-18T22:49:37.601Z	df9ec639-e0a4-486d-a003-87ac82035858	INFO	[dd.trace_id=4215278689475775143 dd.span_id=295333036329706756] Hello, World!  
END RequestId: df9ec639-e0a4-486d-a003-87ac82035858  
REPORT RequestId: df9ec639-e0a4-486d-a003-87ac82035858	Duration: 2136.89 ms	Billed Duration: 2137 ms	Memory Size: 128 MB	Max Memory Used: 123 MB	Init Duration: 832.71 ms  
  
Request ID  
df9ec639-e0a4-486d-a003-87ac82035858  
```  
- Look at your telemetry in Datadog:  
* [Serverless](https://app.datadoghq.com/functions)  
* [Custom metric - coffee_house.order_value](https://app.datadoghq.com/metric/summary?filter=coff&metric=coffee_house.order_value)  