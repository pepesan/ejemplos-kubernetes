#!/bin/bash
POD_NAME=nginx-deployment-758545cb9f-4trcz
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- bash
# dentro del contenedor
# cat /etc/nginx/nginx.conf