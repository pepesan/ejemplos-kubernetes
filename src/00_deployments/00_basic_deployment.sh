#!/bin/bash
# creando un despliegue
kubectl create deployment \
  mi-nginx \
  --image=nginx:latest