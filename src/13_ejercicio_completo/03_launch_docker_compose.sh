#!/bin/bash

# crear el contenedor en base la imagen al Docker hub
## -d ejecuta el contenedor en modo daemon

docker compose up -d

docker compose ps | grep node