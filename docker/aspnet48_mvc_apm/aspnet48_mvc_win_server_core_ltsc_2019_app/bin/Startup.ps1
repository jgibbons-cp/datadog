Set-Content -Path 'C:\\inetpub\\wwwroot\\datadog.json' -Value "{ `"DD_AGENT_HOST`": `"$env:DD_AGENT_HOST`" } "

net stop /y was
net start w3svc

C:\\ServiceMonitor.exe w3svc