#!/bin/bash
POD_NAME=mysql-deployment-678897b5f9-8wq5m
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- /bin/bash
# dentro del contenedor
# echo $MYSQL_DATABASE
# echo $MYSQL_ROOT_PASSWORD