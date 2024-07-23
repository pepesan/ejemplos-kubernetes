#!/bin/bash
# definir el usuario de dockerhub
DOCKER_HUB_USER=pepesan
# Definir el nombre de la imagen o repositorio
DOCKER_HUB_REPOSITORY=node_upload_app
# Definir la versión del Tag
DOCKER_HUB_TAG=1.0.0
# crear el contenedor en base la imagen al Docker hub
## push es el comando principal
## tag: usuario/repositorio:tag
## tag: usuario/nombre_imagen:tag
## -d ejecuta el contenedor en modo daemon
## -p redirecciona el puerto 3001 del host al 3000 de contenedor
docker run -d -p 3001:3000 --name nodeapp -v ./uploads:/app/uploads $DOCKER_HUB_USER/$DOCKER_HUB_REPOSITORY:$DOCKER_HUB_TAG

docker ps | grep node