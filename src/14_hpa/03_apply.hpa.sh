#!/bin/bash
#Aplicando hpa por defecto son 5 minutos para desescalar
kubectl apply -f hpa.yaml
kubectl get hpa
kubectl describe hpa php-apache


