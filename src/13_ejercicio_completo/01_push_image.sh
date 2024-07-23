#!/bin/bash
# definir el usuario de dockerhub
DOCKER_HUB_USER=pepesan
# Definir el nombre de la imagen o repositorio
DOCKER_HUB_REPOSITORY=node_upload_app
# Definir la versión del Tag
DOCKER_HUB_TAG=1.0.0
# Antes de hacer el push hay que hacer el login
# el docker hub
## pedirá usuario y contraseña
docker login -u $DOCKER_HUB_USER
# subir la imagen al Docker hub
## push es el comando principal
## tag: usuario/repositorio:tag
## tag: usuario/nombre_imagen:tag
docker push $DOCKER_HUB_USER/$DOCKER_HUB_REPOSITORY:latest
## define otro tag con la fecha actual
docker push $DOCKER_HUB_USER/$DOCKER_HUB_REPOSITORY:20240723
## define otro tag con la versión de nuestro software
docker push $DOCKER_HUB_USER/$DOCKER_HUB_REPOSITORY:$DOCKER_HUB_TAG
