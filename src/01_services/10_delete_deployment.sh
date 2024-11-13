#!/bin/bash
DEPLOYMENT_NAME=mi-nginx
# creando un despliegue
kubectl delete  -f ./yaml/00_nginx_deployment.yaml