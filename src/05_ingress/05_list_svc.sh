#!/bin/bash
# listar servicios
kubectl get svc
# obtener IP nodo
kubectl get nodes -o wide
# obtener url
minikube service web --url
