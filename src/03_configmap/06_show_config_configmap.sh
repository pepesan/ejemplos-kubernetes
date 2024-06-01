#!/bin/bash
CONFIG_MAP=nginx-config
# mostrar config de configmap
printf "%s\n" $(kubectl get configmap $CONFIG_MAP -o jsonpath='{.data.nginx_conf}')






