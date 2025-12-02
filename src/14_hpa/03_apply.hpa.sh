#!/bin/bash
#Aplicando hpa
kubectl apply -f hpa.yaml
kubectl get hpa
kubectl describe hpa php-apache


