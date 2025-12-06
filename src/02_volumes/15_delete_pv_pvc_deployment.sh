#!/bin/bash
PV_NAME=pv-ejemplo
# borrando PV
kubectl delete pv $PV_NAME

PVC_NAME=pvc-ejemplo-v2
# creando un despliegue
kubectl delete pvc $PVC_NAME

DEPLOY_NAME=nginx-deployment-v2
# creando un despliegue
kubectl delete deployment $DEPLOY_NAME

SERVICE_NAME=nginx-service-v2
# creando un despliegue
kubectl delete svc $SERVICE_NAME