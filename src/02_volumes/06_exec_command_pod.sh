#!/bin/bash
POD_NAME=nginx-deployment-86bdfdc8c5-4llt5
# acceso vía exec command de bash
kubectl exec -it $POD_NAME -- bash