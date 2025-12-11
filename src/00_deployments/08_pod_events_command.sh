#!/bin/bash
POD_NAME=mysql-deployment-dffbcd48-hrr55

# ver los eventos de un pod
kubectl events --for pod/$POD_NAME

## Modo Watch
# kubectl events --for pod/$POD_NAME --watch
## Todos los NS
# kubectl events --all-namespaces