#!/bin/bash

# instalar istio
cd istio-1.22.1
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y

# Posible Salida
# ✔ Istio core installed
#✔ Istiod installed
#✔ Egress gateways installed
#✔ Ingress gateways installed
#✔ Installation complete                                                                                                 Made this installation the default for injection and validation.
