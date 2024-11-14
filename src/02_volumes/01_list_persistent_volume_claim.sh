#!/bin/bash
# para listar persistent volumen claim
kubectl get pvc -o wide
# para listar persistent volumen
kubectl get pv -o wide
# para listar las clases de almacenamiento
kubectl get sc
