#!/bin/bash
POD_NAME=mi-nginx-658b8f94b6-fszxl
# acceso vía exec command de bash
kubectl label pod $POD_NAME miapp=otra
