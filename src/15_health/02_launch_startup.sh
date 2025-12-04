#!/bin/bash
kubectl apply -f startup-demo.yaml
kubectl get pods -w

