#!/bin/bash

# usable en Ubuntu 24.04
# modifica el servicio para que tire de minikube para resolver
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/minikube.conf << EOF
[Resolve]
DNS=$(minikube ip)
Domains=~test
EOF
sudo systemctl restart systemd-resolved
