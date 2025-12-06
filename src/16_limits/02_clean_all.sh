#!/bin/bash

# Elimina el deployment creado
kubectl delete deployment resources-demo --ignore-not-found

# Opcional: observar los pods restantes tras el borrado
kubectl get pods -w



