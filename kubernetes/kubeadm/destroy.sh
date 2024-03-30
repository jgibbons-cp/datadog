#!/bin/bash

# get functions
source ./functions.sh

get_sec_group_id

get_public_ips
remove_ips_from_sec_group

get_private_ips
remove_ips_from_sec_group

# get laptop ip
ip=$(curl -s https://ipinfo.io/ip)
ips=($ip)
remove_ips_from_sec_group

get_instances
terminate_instances
