#!/bin/bash
kubectl apply -f resources-demo.yaml
kubectl get pods -w

