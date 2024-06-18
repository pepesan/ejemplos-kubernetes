#!/bin/bash

# desplegar app de prueba
cd istio-1.22.1
export PATH=$PWD/bin:$PATH

kubectl apply -f samples/addons

kubectl rollout status deployment/kiali -n istio-system