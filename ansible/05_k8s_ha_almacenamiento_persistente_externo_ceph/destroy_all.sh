#!/usr/bin/env bash
# Destruye todo el entorno virtual y limpia archivos temporales.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "════════════════════════════════════════════════════════════════"
echo "  Destruyendo clúster Kubernetes y Ceph Externo en LXD..."
echo "════════════════════════════════════════════════════════════════"

ansible-playbook 20_destroy.yml

echo ""
echo "¡Entorno limpio con éxito!"
