#!/bin/bash
CONFIG_MAP=mysql-configmap
# mostrar config de configmap
printf "%s\n" $(kubectl get configmap $CONFIG_MAP -o jsonpath='{.data.MYSQL_DATABASE}')






