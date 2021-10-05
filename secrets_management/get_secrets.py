#!/usr/bin/env python3

import json
import os
import sys

#set your backend
BACKEND = ""
AZURE = "azure"
TEST = "test"

BACKEND = ""

if BACKEND == AZURE:

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

elif BACKEND == TEST:
    #populate and output it for the secrets manager - example value
    value = "testing"
    secret_response = {"secret2": {"value": value, "error": None}}
else:
    print("No backend defined... exiting...\n")
    sys.exit(-1)

#dump output to stdout
print(json.dumps(secret_response))
