#!/bin/bash
export SERVICE_NAME=service-mi-nodeapp
# acceso a url del servicio
minikube service $SERVICE_NAME --url

# curl http://192.168.49.2:30080
