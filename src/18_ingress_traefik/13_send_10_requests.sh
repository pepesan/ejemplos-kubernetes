#!/bin/bash
SERVER_NAME=miapp.local
# pillamos el puerto del servicio traefik asociado al puerto 80
# kubectl get svc -n traefik -o wide
PORT=31544
for i in {1..10}
do
  echo "Petición $i:"
  curl "$SERVER_NAME:$PORT" | grep Hostname
  echo ""   # línea en blanco para separar
done

