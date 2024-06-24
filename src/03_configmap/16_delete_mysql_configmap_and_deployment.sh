#!/bin/bash
CONFIG_MAP=mysql-configmap
# borrar el configmap de mysql
kubectl delete configmap $CONFIG_MAP
# borrar el despliegue
kubectl delete deployment mysql-deployment
