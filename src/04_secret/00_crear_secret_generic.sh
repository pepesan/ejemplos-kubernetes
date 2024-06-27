#!/bin/bash

# tres tipos de secretos
# generic ú opaque desde fichero directorio o literal
# tls certificado
# docker-registry login del registry

# para crear un secret
kubectl create secret \
  generic \
  mi-secreto \
  --from-literal=key1=supersecret \
  --from-literal=key2=topsecret


