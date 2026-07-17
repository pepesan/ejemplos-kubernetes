#!/usr/bin/env bash
# Destruye el clúster Kubernetes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOG_FILE="ansible.log"

{
  echo "════════════════════════════════════════════════════════════════"
  echo "  [20] Destruir el clúster LXD de Kubernetes"
  echo "════════════════════════════════════════════════════════════════"
  ansible-playbook 20_destroy.yml 2>&1
} | tee "$LOG_FILE"

# Borrar el log al finalizar
echo "Limpiando archivos de logs..."
rm -f "$LOG_FILE"
