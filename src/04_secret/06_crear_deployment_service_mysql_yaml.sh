#!/bin/bash
# crear base 64 de los valores (porque se envía por http/s)
echo "supersecret" | base64
# crear secreto con yaml
kubectl apply -f ./yaml/02_mysql_deployment.yaml


