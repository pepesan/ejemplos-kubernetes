#!/bin/bash
# borrar lo del yaml
kubectl delete -f ./yaml/00_deployment_and_service.yaml
# Borrar ingress
kubectl delete ingress mi-app-ingress
# Desinstalar traefik
helm uninstall traefik -n traefik


