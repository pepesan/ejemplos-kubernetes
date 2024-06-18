#!/bin/bash
# comprobación de servicios
nslookup hello-john.test $(minikube ip)
nslookup hello-jane.test $(minikube ip)
