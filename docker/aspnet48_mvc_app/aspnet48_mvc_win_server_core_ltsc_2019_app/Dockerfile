#Depending on the operating system of the host machines(s) that will build or run the containers, the image specified in the FROM statement may need to be changed.
#For more information, please see https://aka.ms/containercompat 

FROM mcr.microsoft.com/dotnet/framework/sdk:4.8 AS build
WORKDIR /app

COPY *.sln .
COPY *.csproj ./aspnetapp/
COPY *config ./aspnetapp/
RUN nuget restore

COPY . ./aspnetapp/
WORKDIR /app/aspnetapp
RUN msbuild /p:Configuration=Release -r:False

FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019 AS runtime
WORKDIR /inetpub/wwwroot
EXPOSE 80

ARG TRACER_VERSION=2.29.0
ENV DD_TRACER_VERSION=$TRACER_VERSION

# We recommend always using the latest release and regularly updating: https://github.com/DataDog/dd-trace-dotnet/releases/latest
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install Datadog 
RUN Write-Host "Downloading Datadog .NET Tracer v$env:DD_TRACER_VERSION" ;\
    (New-Object System.Net.WebClient).DownloadFile('https://github.com/DataDog/dd-trace-dotnet/releases/download/v' + $env:DD_TRACER_VERSION + '/datadog-dotnet-apm-' + $env:DD_TRACER_VERSION + '-x64.msi', 'datadog-apm.msi') ;\
    Write-Host 'Installing Datadog .NET Tracer' ;\
    Start-Process -Wait msiexec -ArgumentList '/i datadog-apm.msi /quiet /qn /norestart /log datadog-apm-msi-installer.log' ; \
    Write-Host 'Datadog .NET Tracer installed, removing installer file' ; \
	Remove-Item 'datadog-apm.msi' ;

COPY --from=build /app/aspnetapp/. ./
ENTRYPOINT ["powershell.exe", "C:\\inetpub\\wwwroot\\Startup.ps1"]