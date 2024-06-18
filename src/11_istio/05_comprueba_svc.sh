#!/bin/bash

# desplegar app de prueba
cd istio-1.22.1
export PATH=$PWD/bin:$PATH
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -sS productpage:9080/productpage | grep -o "<title>.*</title>"

