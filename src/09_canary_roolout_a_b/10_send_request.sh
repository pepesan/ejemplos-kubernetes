#!/bin/bash
SERVER_NAME=echo.prod.mydomain.com
SERVER_IP=192.168.49.2
# lanza consulta
for i in $(seq 1 10); do curl -s --resolve $SERVER_NAME:80:$SERVER_IP echo.prod.mydomain.com  | grep "Hostname"; done

