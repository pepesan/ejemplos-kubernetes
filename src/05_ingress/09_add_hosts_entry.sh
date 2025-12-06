#!/bin/bash
SERVER_IP=192.168.49.2
SERVER_NAME=hello-world.example
# crea entrada en /etc/hosts
echo "$SERVER_IP $SERVER_NAME" | sudo tee -a /etc/hosts
# lo mostramos
cat /etc/hosts
