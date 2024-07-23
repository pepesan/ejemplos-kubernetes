#!/bin/bash
CHART_NAME=mi-nodeapp
HELM_RELEASE=nodeapp-helm

helm install $HELM_RELEASE ./$CHART_NAME
