#!/bin/bash
SECRET_NAME=mi-secreto
# describir secreto
kubectl get secret $SECRET_NAME -o jsonpath='{.data.key1}' | base64 -d
echo ""
kubectl get secret $SECRET_NAME -o jsonpath='{.data.key2}' | base64 -d
echo ""