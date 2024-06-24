#!/bin/bash
CONFIG_MAP=mi-configmap
# borrar primer configmap
kubectl delete configmap $CONFIG_MAP
# borrar el configmap de nginx con el nginx.conf
kubectl delete configmap nginx-config
# borrar el despliegue
kubectl delete deployment nginx-deployment
