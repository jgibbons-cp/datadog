#!/bin/bash

#create network if it does not exist
source ./create_network.sh

#deploy mysql employees db
docker run --detach --network $lab_network --name=mysql_test --publish 3306:3306 jgibbons-cp/mysql
