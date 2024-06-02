#!/bin/bash
SECRET_NAME=mi-root-mysql-password
# borrar secreto
kubectl delete secret $SECRET_NAME
