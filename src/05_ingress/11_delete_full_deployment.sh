#!/bin/bash
# borrar lo del yaml
kubectl delete -f ./yaml/00_basic_ingress.yaml
kubectl delete svc web
kubectl delete deployment web

