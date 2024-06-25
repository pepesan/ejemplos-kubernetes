#!/bin/bash
kubectl get secrets
# comprobacion
kubectl get secret vault-token -o jsonpath='{.data.token}' | base64 -d
