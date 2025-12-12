#!/bin/bash
# Crea el namespace para Traefik
kubectl create namespace traefik
# Agrega el repositorio de Helm para Traefik
helm repo add traefik https://traefik.github.io/charts
helm repo update
# Instala Traefik usando Helm en el namespace traefik
helm install traefik traefik/traefik \
  --namespace traefik \
  --set service.type=NodePort \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=true \
  --set ingressClass.name=traefik \
  --set providers.kubernetesIngress.enabled=true \
  --set providers.kubernetesIngress.ingressClass=traefik


