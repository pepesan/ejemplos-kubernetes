#!/bin/bash
# borrando el despliegue
kubectl delete -f ./yaml/03_nginx_deployment.yaml
# modificando el despliegue
kubectl delete -f ./yaml/02_nginx_service_nodePort.yaml

