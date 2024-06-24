#!/bin/bash

# para crear un volumen
# entramos a la máquina ssh de minukube
minikube ssh

## tendrás que ejecutar esto a mano
sudo su
export PV_PATH=/mnt/data
# creamos la carpeta
sudo mkdir -p $PV_PATH
# limpiando datos
rm -rf ${PV_PATH:?}/*
# meter contenido
echo "<h2>Hola Mundo</h2>" | sudo tee ${PV_PATH:?}/index.html
# salimos de sudo
exit
# salimos de la máquina ssh
exit
# creando el PV
kubectl apply -f ./yaml/02_persistent_volume.yaml
