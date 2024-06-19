#!/bin/bash
# despliegue de los pod nginx
kubectl apply -f ./yaml/00_nginx_deployment.yaml
# creando un servicio
kubectl expose deployment \
  mi-nginx --type=ClusterIP \
  --name=nginx-service
