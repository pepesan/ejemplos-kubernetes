#!/bin/bash
# definir el usuario de dockerhub
DOCKER_HUB_USER=pepesan
# Definir el nombre de la imagen o repositorio
DOCKER_HUB_REPOSITORY=node_upload_app
# Definir la versión del Tag
DOCKER_HUB_TAG=1.0.0
# construir la imagen en base al Dockerfile
## build es el comando principal
## -t define el tag asociado a la imagen
## tag: usuario/repositorio:tag
## tag: usuario/nombre_imagen:tag
## . pilla el Dockerfile que hay en el directorio actual
docker build -t $DOCKER_HUB_USER/$DOCKER_HUB_REPOSITORY:latest .
## define otro tag con la fecha actual
docker build -t $DOCKER_HUB_USER/$DOCKER_HUB_REPOSITORY:20240723 .
## define otro tag con la versión de nuestro software
docker build -t $DOCKER_HUB_USER/$DOCKER_HUB_REPOSITORY:$DOCKER_HUB_TAG .
