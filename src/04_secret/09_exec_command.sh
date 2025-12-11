#!/bin/bash
POD_NAME=mysql-567f97f8d7-9mcc8
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- /bin/bash

# Dentro del contenedor
# mysql -p
# introducir la bbdd

# Desde fuera
# kubectl get nodes -o wide
# pilla la internal IP del servidor
# kubectl get svc
# pilla el puerto que ha abierto
# mysql -h IP_SERVIDOR -P PUERTO_ABIERTO -u root -p
# mysql -h 192.168.49.2 -P 31185 -u root -p