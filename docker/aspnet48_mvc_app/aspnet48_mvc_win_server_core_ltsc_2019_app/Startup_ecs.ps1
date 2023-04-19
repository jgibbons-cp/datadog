$private_ip = $(curl http://169.254.169.254/latest/meta-data/local-ipv4)
$private_ip = $private_ip.Content
Set-Content -Path 'C:\\inetpub\\wwwroot\\datadog.json' -Value "{ `"DD_AGENT_HOST`": `"$private_ip`" } "

net stop /y was
net start w3svc

C:\\ServiceMonitor.exe w3svc