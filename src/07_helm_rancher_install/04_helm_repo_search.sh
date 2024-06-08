#!/bin/bash

# búsqueda de repos
echo "Repos"
helm search hub rancher -o yaml
# búsqueda de charts
echo "Charts"
helm search repo rancher -o yaml

