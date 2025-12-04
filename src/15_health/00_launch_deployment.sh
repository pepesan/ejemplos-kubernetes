#!/bin/bash
kubectl apply -f healthz.yaml
kubectl describe pod -l app=liveness-demo
kubectl get pods -w
