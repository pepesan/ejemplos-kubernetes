#!/bin/bash

# Borra el deployment dentro del namespace (si aún existe)
kubectl delete deployment team-a-nginx -n team-a --ignore-not-found

# Borra el namespace completo (incluye todo lo que haya dentro)
kubectl delete namespace team-a --ignore-not-found

# Opcional: mostrar los namespaces restantes
kubectl get namespaces




