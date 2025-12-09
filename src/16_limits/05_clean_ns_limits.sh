#!/bin/bash

NAMESPACE="limitado"
LIMITRANGE="lr-cuarta-parte"
RESOURCEQUOTA="rq-cuarta-parte"

echo "Eliminando LimitRange..."
kubectl delete limitrange $LIMITRANGE -n $NAMESPACE --ignore-not-found

echo "Eliminando ResourceQuota..."
kubectl delete resourcequota $RESOURCEQUOTA -n $NAMESPACE --ignore-not-found

echo "Eliminando el namespace completo..."
kubectl delete namespace $NAMESPACE --ignore-not-found

echo "Listo. Todas las limitaciones y el namespace han sido eliminados."




