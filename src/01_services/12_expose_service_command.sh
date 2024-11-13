#!/bin/bash
SERVICE_NAME=nginx-service
# acceso vía exec command de bash
kubectl port-forward service/$SERVICE_NAME 8081:80
# vete a http://localhost:8081/
# si quieres cerrar la exposición
# haz control+C