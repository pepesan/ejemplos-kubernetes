#!/bin/bash
POD_NAME=mi-nginx-56f55ccddb-2mgmh
# acceso vía exec command de bash
kubectl exec -it $POD_NAME bash