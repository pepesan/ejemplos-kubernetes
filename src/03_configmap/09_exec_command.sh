#!/bin/bash
POD_NAME=nginx-deployment-b489587c4-826w4
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- /bin/bash
# dentro del contenedor
# cat /etc/nginx/nginx.conf