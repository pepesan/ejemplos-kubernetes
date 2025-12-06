#!/bin/bash
# CERT_MANAGER_VERSION=v1.14.6
# If you have installed the CRDs manually instead of with the `--set installCRDs=true` option added to your Helm install command, you should upgrade your CRD resources before upgrading the Helm chart:
# kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/$CERT_MANAGER_VERSION/cert-manager.crds.yaml

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart with CRD's and NS
NAMESPACE_NAME=cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace $NAMESPACE_NAME \
  --create-namespace \
  --set installCRDs=true # Instala los CRD's

