#!/bin/bash

minikube start --nodes 2 &&
  kubectl taint node kubernetes.io/hostname=minikube:NoSchedule
