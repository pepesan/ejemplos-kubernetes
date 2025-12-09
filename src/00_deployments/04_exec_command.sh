#!/bin/bash
POD_NAME=mi-nginx-658b8f94b6-fszxl
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- bash