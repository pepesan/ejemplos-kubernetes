#!/bin/bash
POD_NAME=mi-nginx-56f55ccddb-749hq
# acceso vía exec command de bash
kubectl label pod $POD_NAME miapp=otra
