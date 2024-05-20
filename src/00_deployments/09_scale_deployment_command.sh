#!/bin/bash
DEPLOYMENT_NAME=mi-nginx
# acceso vía exec command de bash
kubectl scale deployment $DEPLOYMENT_NAME --replicas 3