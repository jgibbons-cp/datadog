Using Azure Vault with Datadog Integration Configurations
--

This is a sample of how to use Azure Vault secrets with the secrets package to
alleviate clear text variables in Datadog configuration files.  It is based on a
repo from [here](https://github.com/DataDog/dpn/tree/master/scripts/secrets-exe)
and likely will be merged in with it at some point.

Setup
--

The setup here is using an AWS Windows VM, Python, pip and the Azure CLI.  It is assumed for this
example that you have a secret called secret2 in a vault in Azure.  

1) Install python, pip, the Azure cli, and the following libaries.

  - pip install azure-identity
  - pip install azure-keyvault-secrets

2) Create an access policy as noted
[here](https://docs.microsoft.com/en-us/azure/key-vault/secrets/quick-create-python)

 - az keyvault set-policy --name <YourKeyVaultName> --upn user@domain.com --secret-permissions get

3) Set the environment variables returned from the last call so that the user
ddagentuser can access.  I set them in the python code for a quick and dirty
test.... DO NOT SET THEM THERE, but rather set them properly in the environment.

  - AZURE_CLIENT_ID  
  - AZURE_CLIENT_SECRET  
  - AZURE_TENANT_ID

4) In the python code get_secrets.py set the following variale values:  

  - keyVaultName - the value name in your Azure Key Vault  
  - KVUri - the URI of the vault  

5) Test that your Python script works by running python.exe get_secrets.py from
within the same dir you created the file in. Once you see your results, it needs
to be converted to a binary (e.g. .exe).  

6) Run pip install pyinstaller, this is an open source Python to exe
[converter](https://www.pyinstaller.org/)  

7) Next, run pyinstaller.exe --onefile .\get_secrets.py from within the same
directory as get_secrets.py  In the same directory, a new direcoty will be
created after you run this command called dist. cd into the it and run the
new command get_secrets.exe and you should see your secrets output just as they
were with the Python script.  

8) You can now use this application in your Datadog config as outlined
[here](https://docs.datadoghq.com/agent/guide/secrets-management/?tab=windows#providing-an-executable)

Permissions
--

The Datadog Agent won't launch if the permissions are not set properly on the
file, they should be as follows:

 - SYSTEM group has full control
 - Administrators group has full control
 - ddagenteruser (or whatever the Agent's user was named) user has read &
 execute access (full control worked, too)
