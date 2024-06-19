#!/bin/bash
# creando un despliegue
kubectl apply -f ./yaml/00_nginx_deployment.yaml
# creando un servicio
kubectl apply -f ./yaml/01_nginx_service.yaml

