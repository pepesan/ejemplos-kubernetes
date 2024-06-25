#!/bin/bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets \
    external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=true