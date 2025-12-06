#!/bin/bash

# desplegar app de prueba
cd istio-1.22.1
export PATH=$PWD/bin:$PATH
istioctl analyze

# posible salida
# ✔ No validation issues found when analyzing namespace: default.