#!/usr/bin/env bash
# Generic runner for every RKE2 lab: provisions LXD VMs, configures the OS and
# installs RKE2 server (and agent) nodes from the shared playbooks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="ansible.log"

rm -f "$LOG_FILE"

run_step() {
  local numero="$1"
  local fichero="$2"
  local descripcion="$3"

  echo "" | tee -a "$LOG_FILE"
  echo "════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
  echo "  [$numero] $descripcion" | tee -a "$LOG_FILE"
  echo "════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
  sg lxd -c "ansible-playbook \"$fichero\"" 2>&1 | tee -a "$LOG_FILE"
}

run_step 01 "$SCRIPT_DIR/../../base/check_requisitos.yml" "Validate LXD, the lxdbr0 network and the base image"
run_step 02 "$SCRIPT_DIR/01_crear_vms.yml"                "Create the LXD VMs for the RKE2 cluster"
run_step 03 "$SCRIPT_DIR/02_configurar_os.yml"            "Configure the operating system and kernel modules"
run_step 04 "$SCRIPT_DIR/03_instalar_rke2_server.yml"     "Install and configure the RKE2 Server node(s)"

if grep -q "\[rke2_workers\]" inventory.ini 2>/dev/null && grep -A 10 "\[rke2_workers\]" inventory.ini | grep -v "^#" | grep -v "^\[" | grep -q "="; then
  run_step 05 "$SCRIPT_DIR/04_instalar_rke2_agent.yml"    "Install and join the RKE2 Worker / Agent node(s)"
fi

SERVER_IP=$(awk '/^rke2-server1/ { for (i=1;i<=NF;i++) if ($i ~ /^ansible_host=/) print substr($i, index($i, "=")+1) }' inventory.ini)

{
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  RKE2 cluster deployed and ready!"
  echo "  "
  echo "  SSH into the server node:"
  echo "  ssh root@${SERVER_IP}"
  echo "  "
  echo "  Use kubectl from your local host:"
  echo "  export KUBECONFIG=\$(pwd)/kubeconfig.yaml"
  echo "  kubectl get nodes -o wide"
  echo "  "
  echo "  To destroy the lab: ./destroy_all.sh"
  echo "════════════════════════════════════════════════════════════════"
} | tee -a "$LOG_FILE"
