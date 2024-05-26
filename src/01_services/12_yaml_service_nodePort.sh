#!/bin/bash
# creando un despliegue
kubectl apply -f ./yaml/02_nginx_service_nodePort.yaml
# Para saber la IP del servidor (External/Internal-IP (docker))
kubectl get nodes -o wide
export SERVICE_NAME=nginx-service
# acceso a url del servicio
minikube service $SERVICE_NAME --url
