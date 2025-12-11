#!/bin/bash
POD_NAME=mysql-deployment-dffbcd48-t7wv5
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- /bin/bash
# dentro del contenedor
# echo $MYSQL_DATABASE
# echo $MYSQL_ROOT_PASSWORD