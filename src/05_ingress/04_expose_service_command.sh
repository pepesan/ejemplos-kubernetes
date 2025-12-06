#!/bin/bash
SERVICE_NAME=web
# acceso vía exec command de bash
kubectl expose deployment $SERVICE_NAME --type=NodePort --port=8080
