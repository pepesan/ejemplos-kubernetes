#!/bin/bash
POD_NAME=nginx-deployment-v2-69f5c896f8-qks22
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- bash