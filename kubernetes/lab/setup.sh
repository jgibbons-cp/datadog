#!/bin/bash

minikube start --nodes 3 &&
  kubectl taint node minikube-m03 env=dev:NoSchedule
