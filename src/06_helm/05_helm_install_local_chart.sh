#!/bin/bash
CHART_NAME=mi-nginx-chart
HELM_RELEASE=nginx-helm
helm install $HELM_RELEASE ./charts/$CHART_NAME-0.1.0.tgz
# helm install $HELM_RELEASE ./charts/$CHART_NAME

# instalación con values custom
# helm install $HELM_RELEASE \
# -f ./charts/nginx-values.yaml  \
# ./charts/$CHART_NAME-0.1.0.tgz
