#!/bin/bash
CONFIG_MAP=mi-configmap
# describir configmap
kubectl delete configmap $CONFIG_MAP
kubectl delete deployment nginx-deployment
