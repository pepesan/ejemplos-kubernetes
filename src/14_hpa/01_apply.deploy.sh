#!/bin/bash
#Aplicando deployment
kubectl apply -f deployment-hpa.yaml
kubectl get pods -l app=php-apache
