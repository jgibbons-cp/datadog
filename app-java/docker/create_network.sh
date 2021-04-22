#!/bin/bash

#create docker network if it does not exist
lab_network=lab
docker network ls | grep $lab_network > /dev/null
if [ "$?" -eq "1" ]
then
  docker network create $lab_network;
  echo "created $lab_network network..."
else
  echo "$lab_network network already exists, we are good... moving on..."
fi
