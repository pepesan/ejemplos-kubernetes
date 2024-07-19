#!/bin/bash


kubectl get nodes -o wide
export SERVICE_NAME=nginx-service-v2
# acceso a url del servicio
minikube service $SERVICE_NAME --url
## Recuerda deshabilitar la cache del navegador
## O bien abre una sesion en incognito

