#!/bin/bash

# aws region
region=us-west-1

# for aws credentials
profile=default

# for filtering out aws resources
tag_key=cluster
tag_value=kubeadm

get_sec_group_id () {
    sec_group_id=None

    while [ "$sec_group_id" = "None" ]
    do
        echo "checking on node to be in a running state...\n"

        # get security groupid
        sec_group_id=$(aws --region $region \
            ec2 describe-instances \
            --profile $profile \
            --filters \
            "Name=instance-state-name,Values=running" \
            "Name=tag:$tag_key,Values=$tag_value" \
            --query 'Reservations[0].Instances[0].SecurityGroups[0].[GroupId]'\
            --output text)
        sleep 5
    done

    echo 'ok, got security group '"$sec_group_id"'\n'
}

get_public_ips () {
    # get public ips
    public_ips=$(aws --region $region \
        ec2 describe-instances \
        --profile $profile \
        --filters \
        "Name=instance-state-name,Values=running" \
        "Name=tag:$tag_key,Values=$tag_value" \
        --query 'Reservations[*].Instances[*].[PublicIpAddress]' \
        --output text)

    # move them to an array
    ips=($public_ips)
}

get_private_ips () {
    private_ips=$(aws --region $region \
        ec2 describe-instances \
        --profile $profile \
        --filters \
        "Name=instance-state-name,Values=running" \
        "Name=tag:$tag_key,Values=$tag_value" \
        --query 'Reservations[*].Instances[*].[PrivateIpAddress]' \
        --output text)

    # move them to an array
    ips=($private_ips)
}

remove_ips_from_sec_group () {
    # remove from sec group
    for i in ${!ips[@]}; do
        aws ec2 revoke-security-group-ingress \
            --profile $profile \
            --region $region \
            --group-id $sec_group_id \
            --protocol all \
            --cidr ${ips[$i]}/32 > /dev/null
        echo 'removed '"${ips[$i]}"'/32 from security group...\n'
    done
}

add_ips_to_sec_group () {
    # remove from sec group
    for i in ${!ips[@]}; do
        aws ec2 authorize-security-group-ingress \
            --profile $profile \
            --region $region \
            --group-id $sec_group_id \
            --protocol all \
            --cidr ${ips[$i]}/32 > /dev/null
        echo 'added '"${ips[$i]}"'/32 to security group...\n'
    done
}

get_instances () {
    instance_data=$(aws --region $region \
    ec2 describe-instances \
        --filters "Name=tag:$tag_key,Values=$tag_value" \
        "Name=instance-state-name,Values=running"\
        --profile $profile \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text)

    instances=($instance_data)
}

terminate_instances () {
    for i in ${!instances[@]}; do
        aws ec2 terminate-instances \
            --profile $profile \
            --region $region \
            --instance-ids ${instances[$i]} > /dev/null
        echo 'Terminated instance '"${instances[$i]}"'...\n'
    done
}
