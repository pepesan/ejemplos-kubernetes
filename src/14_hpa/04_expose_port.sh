#!/bin/bash
#exponiendo puerto al servicio
kubectl port-forward deployment/php-apache 8080:80



