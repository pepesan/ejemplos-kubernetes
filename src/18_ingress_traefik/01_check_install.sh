#!/bin/bash
# verificar la instalacion de traefik
kubectl get pods -n traefik
# verificar los servicios de traefik
kubectl get svc -n traefik -o wide



