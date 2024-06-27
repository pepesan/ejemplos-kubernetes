#!/bin/bash
CHART_NAME=mi-nginx-chart
HELM_RELEASE=nginx-helm
helm upgrade $HELM_RELEASE ./charts/$CHART_NAME

