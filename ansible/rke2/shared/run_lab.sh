#!/usr/bin/env bash
# Helper genérico para ejecutar laboratorios RKE2
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

run_step 01 "$SCRIPT_DIR/../../base/check_requisitos.yml" "Validar LXD, red lxdbr0 e imagen base"
run_step 02 "$SCRIPT_DIR/01_crear_vms.yml"                "Crear VMs LXD para el clúster RKE2"
run_step 03 "$SCRIPT_DIR/02_configurar_os.yml"            "Configurar sistema operativo y módulos de kernel"
run_step 04 "$SCRIPT_DIR/03_instalar_rke2_server.yml"     "Instalar y configurar RKE2 Server Node(s)"

if grep -q "\[rke2_workers\]" inventory.ini 2>/dev/null && grep -A 10 "\[rke2_workers\]" inventory.ini | grep -v "^#" | grep -v "^\[" | grep -q "="; then
  run_step 05 "$SCRIPT_DIR/04_instalar_rke2_agent.yml"    "Instalar y conectar RKE2 Worker / Agent Node(s)"
fi

SERVER_IP=$(awk '/^rke2-server1/ { for (i=1;i<=NF;i++) if ($i ~ /^ansible_host=/) print substr($i, index($i, "=")+1) }' inventory.ini)

{
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  ¡Clúster RKE2 desplegado y listo!"
  echo "  "
  echo "  Para conectarte por SSH al Server Node:"
  echo "  ssh root@${SERVER_IP}"
  echo "  "
  echo "  Para usar kubectl desde tu host local:"
  echo "  export KUBECONFIG=\$(pwd)/kubeconfig.yaml"
  echo "  kubectl get nodes -o wide"
  echo "  "
  echo "  Para destruir el laboratorio: ./destroy_all.sh"
  echo "════════════════════════════════════════════════════════════════"
} | tee -a "$LOG_FILE"
