#!/bin/bash
POD_NAME=nginx-deployment-5bb7974b77-hc7xz
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- /bin/bash
# dentro del contenedor
# cat /etc/nginx/nginx.conf