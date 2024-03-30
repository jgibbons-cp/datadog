#!/bin/bash
source ./functions.sh

# template for infra
launch_template_id=<your_template_id>
node_count=2

tag_spec='ResourceType=instance,Tags=[{Key='"$tag_key"',Value='"$tag_value"'}]'
# launch vms from template
aws ec2 run-instances --profile=$profile --region=$region \
    --launch-template LaunchTemplateId=$launch_template_id \
    --count=$node_count \
    --tag-specifications=$tag_spec > /dev/null

error_code=$?

# let's bail if there is an error
if [ "$error_code" -ne "0" ]; then
    echo "\nExiting...\n"
    exit $error_code
fi

get_sec_group_id

get_public_ips
add_ips_to_sec_group

get_private_ips
add_ips_to_sec_group

# get client ip
laptop_ip=$(curl -s https://ipinfo.io/ip)
ips=($laptop_ip)

add_ips_to_sec_group

# create cluster
sh create_cluster.sh ${public_ips[@]}
