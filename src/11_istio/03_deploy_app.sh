#!/bin/bash

# desplegar app de prueba
cd istio-1.22.1
export PATH=$PWD/bin:$PATH
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml


