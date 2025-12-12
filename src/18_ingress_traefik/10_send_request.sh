#!/bin/bash
SERVER_NAME=miapp.local
# pillamos el puerto del servicio traefik asociado al puerto 80
# kubectl get svc -n traefik -o wide
PORT=31544
# lanza consulta
curl $SERVER_NAME:$PORT

