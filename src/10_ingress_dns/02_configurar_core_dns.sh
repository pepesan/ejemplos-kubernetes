#!/bin/bash

# necesitamos saber la ip del servidor minikube
minikube ip
# modifica el configmap de coredns
kubectl edit configmap coredns -n kube-system

# Debes Añadir esto en el Corefile y antes del kind:
# Cambia el IP_MINUKUBE por la ip de minikube
# test:53 {
#            errors
#            cache 30
#            forward . IP_MINIKUBE
# }
# Ejemplo de fichero
## Please edit the object below. Lines beginning with a '#' will be ignored,
 ## and an empty file will abort the edit. If an error occurs while saving this file will be
 ## reopened with the relevant failures.
 ##
 #apiVersion: v1
 #data:
 #  Corefile: |
 #    .:53 {
 #        log
 #        errors
 #        health {
 #           lameduck 5s
 #        }
 #        ready
 #        kubernetes cluster.local in-addr.arpa ip6.arpa {
 #           pods insecure
 #           fallthrough in-addr.arpa ip6.arpa
 #           ttl 30
 #        }
 #        prometheus :9153
 #        hosts {
 #           192.168.49.1 host.minikube.internal
 #           fallthrough
 #        }
 #        forward . /etc/resolv.conf {
 #           max_concurrent 1000
 #        }
 #        cache 30
 #        loop
 #        reload
 #        loadbalance
 #    }
 #    test:53 {
 #            errors
 #            cache 30
 #            forward . 192.168.49.2
 #    }
 #kind: ConfigMap
 #metadata:
 #  creationTimestamp: "2024-06-18T11:06:39Z"
 #  name: coredns
 #  namespace: kube-system