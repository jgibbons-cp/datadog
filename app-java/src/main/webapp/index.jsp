<%@ page language="java"
  contentType="text/html; charset=ISO-8859-1"
  pageEncoding="ISO-8859-1"%>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
    <title>Tomcat JDBC Example</title>
    <script src="https://www.datadoghq-browser-agent.com/datadog-rum.js" type="text/javascript"></script>
    <script type="text/javascript" src="https://www.datadoghq-browser-agent.com/datadog-logs.js"></script>
    <script>
      <%
        /*get Datadog token and id from env and set them in init*/
        String clientToken = "";
        clientToken = System.getenv("CLIENT_TOKEN");
        String applicationId = "";
        applicationId = System.getenv("APPLICATION_ID");
      %>
      window.DD_RUM &&
          window.DD_RUM.init({
              clientToken: "<%=clientToken%>",
              applicationId: "<%=applicationId%>",
              site: 'datadoghq.com',
              service: 'app-java',
              env: 'lab',
              version: '.01',
              sampleRate: 100,
              trackInteractions: true,
              allowedTracingOrigins: [window.location.origin]
          })
      window.DD_LOGS &&
          DD_LOGS.init({
              clientToken: "<%=clientToken%>",
              site: 'datadoghq.com',
              forwardErrorsToLogs: true,
              sampleRate: 100,
          })
      DD_LOGS.logger.info('Added ' + window.location.origin + ' to allowedTracingOrigins.')
    </script>
    <script>
      function call(url, method = "POST", payload) {
        var xhttp = new XMLHttpRequest();
        xhttp.onreadystatechange = function () {
          if (this.readyState == 4 && this.status == 200) {
              document.getElementById("response").innerHTML = this.responseText;
          }
        };
        xhttp.open(method, url, true);
        xhttp.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        name = document.getElementById('last_name').value;
        xhttp.send(payload + '&' + 'last_name=' + name);
      }
    </script>
  </head>
  <body>
    <form>
      <label for="lname">Last name: </label><input type="text" id="last_name" value="Facello" /></br>
      </br>
      <button type="button" onclick="call(window.location.origin+'${pageContext.request.contextPath}/query?', 'POST', 'jdbc_query')">Query DB</button></br>
      <pre id="response"></pre>
      </form>
  </body>
</html>
