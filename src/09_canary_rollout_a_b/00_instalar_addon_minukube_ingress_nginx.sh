#!/bin/bash

# instalar el addon de ingress nginx
minikube addons enable ingress
# Instalación con Helm
# helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# helm repo update
# helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace --wait --debug


