#!/bin/bash
POD_NAME=nginx-deployment-568696c96c-ffc2j
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- bash