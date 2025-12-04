#!/bin/bash
kubectl create namespace team-a
kubectl apply -f team-a-deployment.yaml
kubectl get pods -n team-a -w
