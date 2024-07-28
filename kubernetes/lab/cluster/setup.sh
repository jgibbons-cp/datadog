#!/bin/bash

minikube start --nodes 2 &&
  kubectl taint node minikube-m03 =dev:NoSchedule
