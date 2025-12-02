#!/bin/bash
# limpiar todo
kubectl delete -f hpa.yaml
kubectl delete -f service-hpa.yaml
kubectl delete -f deployment-hpa.yaml



