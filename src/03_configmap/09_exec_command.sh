#!/bin/bash
POD_NAME=nginx-deployment-5d975c77fc-ppzms
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- /bin/bash
# dentro del contenedor
# cat /etc/nginx/nginx.conf