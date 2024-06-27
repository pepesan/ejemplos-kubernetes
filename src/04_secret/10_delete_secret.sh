#!/bin/bash
SECRET_NAME=mi-secreto
# borrar secreto
kubectl delete secret $SECRET_NAME
