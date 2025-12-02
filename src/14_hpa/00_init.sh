#!/bin/bash
# Instalación de metric server
minikube addons enable metrics-server

# Comprobación
kubectl get pods -n kube-system | grep metrics-server
