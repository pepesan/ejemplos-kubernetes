#!/bin/bash
POD_NAME=mi-nginx-658b8f94b6-7k9tq
# acceso vía exec command de bash
kubectl label pod $POD_NAME miapp=otra
