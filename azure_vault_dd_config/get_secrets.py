#!/usr/bin/env python3

import os
import json
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential

#DO NOT SET THESE HERE - quick and dirty from someone who can't figure out
#windows
os.environ["AZURE_CLIENT_ID"] = ""
os.environ["AZURE_CLIENT_SECRET"] = ""
os.environ["AZURE_TENANT_ID"] = ""

#vault info
keyVaultName = ""
KVUri = f""

#authenticate
credential = DefaultAzureCredential()
client = SecretClient(vault_url=KVUri, credential=credential)

#get the secret - this assumes a name
secretName = "secret2"
secret2 = client.get_secret(secretName)
secret_response = {}

#populate and output it for the secrets manager
secret_response = {"secret2": {"value": secret2.value, "error": None}}
print(json.dumps(secret_response))
