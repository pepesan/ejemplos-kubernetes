#!/bin/bash
NAMESPACE_NAME=cattle-system
SERVICE_NAME=rancher
# acceso vía exec command de bash
kubectl port-forward \
  -n $NAMESPACE_NAME \
  service/$SERVICE_NAME \
  8443:443

# entrar
# https://localhost:8443
# pedirá la contraseña de bootstrap
# pedirá meter nueva contraseña (12 chars min)
# dos veces
# pedirá confirmar la url de acceso