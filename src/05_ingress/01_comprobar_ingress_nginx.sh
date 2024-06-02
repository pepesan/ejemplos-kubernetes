#!/bin/bash
# comprobar la instalación del addon de ingress nginx
kubectl get pods -n ingress-nginx
# debería salir algo similar a
#NAME                                       READY   STATUS      RESTARTS   AGE
#ingress-nginx-admission-create-x9l8j       0/1     Completed   0          40s
#ingress-nginx-admission-patch-x2c25        0/1     Completed   1          40s
#ingress-nginx-controller-84df5799c-xm6sx   1/1     Running     0          40s


