#!/bin/bash
RANCHER_HOSTNAME=rancher.local
# crea entrada en /etc/hosts
echo "127.0.0.1 $RANCHER_HOSTNAME" | sudo tee -a /etc/hosts
# lo mostramos
cat /etc/hosts
