#!/bin/bash
#Aplicando service
kubectl apply -f service-hpa.yaml
kubectl get svc php-apache

