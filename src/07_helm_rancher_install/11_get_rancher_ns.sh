#!/bin/bash
NAMESPACE_NAME=cattle-system
echo "Namespaces"
kubectl get ns
echo "Pods by namespace"
kubectl get pod -n $NAMESPACE_NAME
echo "RollOut"
kubectl -n $NAMESPACE_NAME rollout status deploy/rancher
# esperar al:
# deployment "rancher" successfully rolled out
