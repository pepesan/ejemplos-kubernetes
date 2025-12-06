#!/bin/bash
echo "Namespaces"
kubectl get ns
echo "Pods by namespace"
kubectl get pod -n cert-manager
# Pods by namespace
#NAME                                       READY   STATUS    RESTARTS   AGE
#cert-manager-cainjector-698464d9bb-zscxp   1/1     Running   0          26s
#cert-manager-d7db49bf4-5c88r               1/1     Running   0          26s
#cert-manager-webhook-f6c9958d-mqflg        1/1     Running   0          26s

