#!/bin/bash

minikube start --nodes 2 &&
  kubectl taint node minikube kubernetes.io/hostname=minikube:NoSchedule
