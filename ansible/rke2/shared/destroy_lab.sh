#!/usr/bin/env bash
# Generic teardown for every RKE2 lab: deletes the inventory VMs and local artifacts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Destroying the RKE2 cluster VMs..."
sg lxd -c "ansible-playbook \"$SCRIPT_DIR/destroy_vms.yml\"" 2>&1 || true

# Run any lab-specific teardown playbooks present in the lab directory
# (destroy_*.yml, e.g. removing the local registry container in lab 06).
shopt -s nullglob
for pb in destroy_*.yml; do
  echo "Running lab-specific teardown: $pb"
  sg lxd -c "ansible-playbook \"$PWD/$pb\"" 2>&1 || true
done
shopt -u nullglob

rm -f kubeconfig.yaml ansible.log rke2_install.log

echo "RKE2 lab destroyed and cleaned up."
