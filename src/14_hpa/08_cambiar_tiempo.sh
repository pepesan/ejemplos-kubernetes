#!/bin/bash
# cambiar tiempo por defecto son 5 minutos
kubectl patch hpa php-apache --type='merge' -p '{
  "spec": {
    "behavior": {
      "scaleDown": {
        "stabilizationWindowSeconds": 30
      }
    }
  }
}'




