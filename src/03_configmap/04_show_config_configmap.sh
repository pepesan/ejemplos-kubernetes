#!/bin/bash
CONFIG_MAP=mi-configmap
# mostrar config de configmap
printf "%s\n" $(kubectl get configmap $CONFIG_MAP -o jsonpath='{.data.clave}')






