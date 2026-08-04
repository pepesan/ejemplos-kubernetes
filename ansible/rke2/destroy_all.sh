#!/usr/bin/env bash
# Script para destruir las VMs de RKE2 y limpiar archivos temporales.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Destruyendo VM rke2-server1 en LXD..."
sg lxd -c "lxc delete -f rke2-server1 2>/dev/null" || true

rm -f kubeconfig.yaml rke2_install.log

echo "Entorno RKE2 destruido y limpiado."
