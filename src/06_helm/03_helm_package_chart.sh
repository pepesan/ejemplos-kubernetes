#!/bin/bash
CHART_NAME=mi-nginx-chart
cd charts

helm package $CHART_NAME

ls -la $CHART_NAME-0.1.0.tgz
