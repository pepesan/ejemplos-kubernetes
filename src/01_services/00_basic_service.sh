#!/bin/bash
# creando un despliegue
kubectl expose deployment \
  mi-nginx --type=ClusterIP \
  --name=nginx-service
