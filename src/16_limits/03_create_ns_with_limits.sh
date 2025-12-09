#!/bin/bash
# crea el namespace
kubectl create namespace limitado

# Aplica los límites totales del namespace
kubectl apply -f resourcequota-cuarta-parte.yaml



