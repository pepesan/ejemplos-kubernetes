#!/bin/bash
# desplegar servidor nginx
kubectl create deployment web --image=gcr.io/google-samples/hello-app:1.0
