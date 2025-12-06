#!/bin/bash
NAMESPACE_NAME=cattle-system
# crea NS
kubectl create namespace $NAMESPACE_NAME
echo "Namespaces"
kubectl get ns
echo "Pods by namespace"
kubectl get pod -n $NAMESPACE_NAME

