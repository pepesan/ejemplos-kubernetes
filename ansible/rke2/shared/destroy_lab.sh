#!/usr/bin/env bash
# Generic teardown for every RKE2 lab: deletes the inventory VMs and local artifacts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Destroying the RKE2 cluster VMs..."
sg lxd -c "ansible-playbook \"$SCRIPT_DIR/destroy_vms.yml\"" 2>&1 || true

rm -f kubeconfig.yaml ansible.log rke2_install.log

echo "RKE2 lab destroyed and cleaned up."
