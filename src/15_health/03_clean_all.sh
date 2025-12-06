#!/bin/bash

# Elimina los tres despliegues creados
kubectl delete deployment liveness-demo --ignore-not-found
kubectl delete deployment readiness-demo --ignore-not-found
kubectl delete deployment startup-demo --ignore-not-found

# Opcional: mostrar el estado de los pods después del borrado
kubectl get pods -w

