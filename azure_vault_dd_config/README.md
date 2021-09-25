Using Azure Vault with Datadog Integration Configurations
--

This is a sample of how to use Azure Vault secrets with the secrets package to
alleviate clear text variables in Datadog configuration files.  It is based on a
repo from [here](https://github.com/DataDog/dpn/tree/master/scripts/secrets-exe)
and may be merged in with it at some point.

Setup
--

The setup here is using an AWS Windows 2019 VM, Python, pip and the Azure CLI.  
It is assumed for this example that you have a secret called secret2 in a vault
in Azure.  

1) Install python, pip, the Azure cli, the Datadog agent and the following
libraries.

  - ```pip install azure-identity```
  - ```pip install azure-keyvault-secrets```
  - [CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli)

2) Create an Active Directory application and create an auth policy as noted
[here](https://docs.microsoft.com/en-us/python/api/overview/azure/keyvault-secrets-readme?view=azure-python#retrieve-a-secret)  

 - az ad sp create-for-rbac --name http://my-application --skip-assignment  

Create an access policy as noted
[here](https://docs.microsoft.com/en-us/azure/key-vault/secrets/quick-create-python)  

The AZURE_CLIENT_ID will come from the return json in the rbac call.  

 - az keyvault set-policy --name <YourKeyVaultName> --upn <AZURE_CLIENT_ID> --secret-permissions get

3) Set the environment variables returned from the RBAC call so that the user
ddagentuser can access them from a python program.  I set them in the python
code for a quick and dirty test.... DO NOT SET THEM THERE, but rather set them
properly in the environment.

  - AZURE_CLIENT_ID  
  - AZURE_CLIENT_SECRET  
  - AZURE_TENANT_ID

4) In the python code get_secrets.py set the following variable values:  

  - keyVaultName - the value name in your Azure Key Vault  
  - KVUri - the URI of the vault  

5) Test that your Python script works by running python.exe get_secrets.py from
within the same directory where you created the file. Once you see your results,
 it needs to be converted to a binary (e.g. .exe on Windows).  

6) Run ```pip install pyinstaller```, this is an open source Python to exe
[converter](https://www.pyinstaller.org/)  

7) Next, run ```pyinstaller.exe --onefile .\get_secrets.py``` from within the same
directory as get_secrets.py  In the same directory, a new directory will be
created after you run this command called dist. ```cd``` into the it and run the
new command ```.\get_secrets.exe``` and you should see your secrets output just
as they were with the Python script.  

8) You can now use this application in your Datadog config as outlined
[here](https://docs.datadoghq.com/agent/guide/secrets-management/?tab=windows#providing-an-executable)

Note, in the datadog.yaml you will need the following:

```secret_backend_command: <path_to_executable>
#example argument
secret_backend_arguments:
  - secret2
```

Permissions
--

The Datadog Agent will drop the integration if the permissions are not set
properly on the file, they should be as follows:

 - SYSTEM group has full control
 - Administrators group has full control
 - ddagenteruser (or whatever the Agent's user was named) user has read &
 execute access (full control worked, too)
