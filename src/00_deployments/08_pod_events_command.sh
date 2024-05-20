#!/bin/bash
POD_NAME=mi-nginx-56f55ccddb-t5mg6

# ver los eventos de un pod
kubectl events --for pod/$POD_NAME

## Modo Watch
# kubectl events --for pod/$POD_NAME --watch
## Todos los NS
# kubectl events --all-namespaces