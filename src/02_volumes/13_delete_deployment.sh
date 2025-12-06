#!/bin/bash
DEPLOY_NAME=nginx-deployment
# borrando un despliegue
kubectl delete deployment $DEPLOY_NAME
