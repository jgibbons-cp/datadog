# from IAM roles for task container bootstrap script at https://docs.aws.amazon.com/AmazonECS/latest/developerguide/windows_task_IAM_roles.html
$gateway = (Get-NetRoute | Where { $_.DestinationPrefix -eq '0.0.0.0/0' } | Sort-Object RouteMetric | Select NextHop).NextHop
$ifIndex = (Get-NetAdapter -InterfaceDescription "Hyper-V Virtual Ethernet*" | Sort-Object | Select ifIndex).ifIndex
New-NetRoute -DestinationPrefix 169.254.170.2/32 -InterfaceIndex $ifIndex -NextHop $gateway -PolicyStore ActiveStore # credentials API
New-NetRoute -DestinationPrefix 169.254.169.254/32 -InterfaceIndex $ifIndex -NextHop $gateway -PolicyStore ActiveStore # metadata API

$private_ip = $(curl -UseBasicParsing http://169.254.169.254/latest/meta-data/local-ipv4)
$private_ip = $private_ip.Content
Set-Content -Path 'C:\\inetpub\\wwwroot\\datadog.json' -Value "{ `"DD_AGENT_HOST`": `"$private_ip`" } "

net stop /y was
net start w3svc

C:\\ServiceMonitor.exe w3svc
