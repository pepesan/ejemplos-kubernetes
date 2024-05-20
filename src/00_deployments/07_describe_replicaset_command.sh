#!/bin/bash
REPLICASET_NAME=mi-nginx-56f55ccddb
# acceso vía exec command de bash
kubectl describe replicaset $REPLICASET_NAME