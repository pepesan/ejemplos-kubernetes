#!/bin/bash
kubectl apply -f readiness-demo.yaml
kubectl get pods -w
