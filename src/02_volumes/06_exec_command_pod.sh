#!/bin/bash
POD_NAME=nginx-deployment-76c9b54b6c-pvcxx
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- bash