#!/bin/bash
NAMESPACE_NAME=cattle-system
# despliegues
kubectl -n $NAMESPACE_NAME get deploy rancher
# NAME      READY   UP-TO-DATE   AVAILABLE   AGE
# rancher   3/3     3            3           5m48s
# servicios
kubectl -n $NAMESPACE_NAME get svc -o wide
# servicio rancher
kubectl -n $NAMESPACE_NAME describe svc rancher
# nodos
kubectl get nodes -o wide


