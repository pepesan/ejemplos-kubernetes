#!/usr/bin/env bash
# Helper genérico para destruir laboratorios RKE2
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Destruyendo VMs del clúster RKE2..."
sg lxd -c "ansible-playbook \"$SCRIPT_DIR/destroy_vms.yml\"" 2>&1 || true

rm -f kubeconfig.yaml ansible.log rke2_install.log

echo "Laboratorio RKE2 destruido y limpiado."
