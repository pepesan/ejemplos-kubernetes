#!/bin/bash
CHART_NAME=mi-nginx-chart
# Ruta del archivo Values YAML
archivo_values_yaml="charts/$CHART_NAME/values.yaml"

# Valor nuevo de replicaCount
replicaCount=2

# Editar el archivo YAML
sed -i "s/replicaCount: 1/replicaCount: $replicaCount/" $archivo_values_yaml

# Verificar el cambio
echo "Contenido de $archivo_values_yaml después de la edición:"
cat $archivo_values_yaml

# Ruta del archivo Values YAML
archivo_chart_yaml="charts/$CHART_NAME/Chart.yaml"

# Valor nuevo de replicaCount
chart_version=0.2.0

# Editar el archivo YAML
sed -i "s/version: 0.1.0/version: $chart_version/" $archivo_chart_yaml

# Verificar el cambio
echo "Contenido de $archivo_chart_yaml después de la edición:"
cat $archivo_chart_yaml
