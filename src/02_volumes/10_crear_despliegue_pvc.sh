#!/bin/bash

# para crear un pvc
kubectl apply -f ./yaml/03_persistent_volume_claim.yaml
# creando el despliegue
kubectl apply -f ./yaml/04_deployment_with_pvc.yaml

