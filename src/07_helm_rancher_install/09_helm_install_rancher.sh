#!/bin/bash
REPO_TYPE=latest
RANCHER_HOSTNAME=rancher.local
RANCHER_PASSWORD=admin
# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart with CRD's and NS
helm install rancher rancher-$REPO_TYPE/rancher \
  --namespace cattle-system \
  --set hostname=$RANCHER_HOSTNAME \
  --set bootstrapPassword=$RANCHER_PASSWORD

# Install with letsencrypt
# para que funcione debemos tener un registro DNS
# apuntando a la ip de la máquina con el mismo
# nombre del RANCHER_HOSTNAME
#LETSENCRYPT_EMAIL=me@example.org
#helm install rancher rancher-$REPO_TYPE/rancher \
#  --namespace cattle-system \
#  --set hostname=$RANCHER_HOSTNAME \
#  --set bootstrapPassword=$RANCHER_PASSWORD \
#  --set ingress.tls.source=letsEncrypt \
#  --set letsEncrypt.email=$LETSENCRYPT_EMAIL \
#  --set letsEncrypt.ingress.class=nginx
