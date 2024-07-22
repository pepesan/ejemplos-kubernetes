#!/bin/bash
POD_NAME=nginx-deployment-9fd786c8b-s4f7h
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- /bin/bash
# dentro del contenedor
# cat /etc/nginx/nginx.conf