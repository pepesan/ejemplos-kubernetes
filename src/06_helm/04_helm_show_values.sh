#!/bin/bash
CHART_NAME=mi-nginx-chart
cd charts

helm show values $CHART_NAME >> values.yaml

ls -la values.yaml
