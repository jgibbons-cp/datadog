#!/bin/bash

bash create_lab_cluster.sh
if [ $? -ne 0 ]; then
    echo "Error: There appears to be an issue with the cluster... exiting setup..."
    exit 1
fi

bash create_configure_storage.sh
if [ $? -ne 0 ]; then
    echo "Error: There appears to be an issue with the storage... exiting setup..."
    exit 1
fi

bash create_postgresql.sh
if [ $? -ne 0 ]; then
    echo "Error: There appears to be an issue with postgresql... exiting setup..."
    exit 1
fi

bash install_byoc.sh
if [ $? -ne 0 ]; then
    echo "Error: There appears to be an issue with BYOC... exiting setup..."
    exit 1
fi