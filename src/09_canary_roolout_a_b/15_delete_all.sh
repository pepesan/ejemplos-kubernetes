#!/bin/bash
# quitar ingress
kubectl delete ingress production
kubectl delete ingress canary

# quitar svc
kubectl delete svc production
kubectl delete svc canary

# quitar deployment
kubectl delete deployment production
kubectl delete deployment canary