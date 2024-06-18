#!/bin/bash

# instalar istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.22.1
export PATH=$PWD/bin:$PATH

