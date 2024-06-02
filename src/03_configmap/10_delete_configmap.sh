#!/bin/bash
CONFIG_MAP=mi-configmap
# borrar configmap
kubectl delete configmap $CONFIG_MAP
kubectl delete deployment nginx-deployment
