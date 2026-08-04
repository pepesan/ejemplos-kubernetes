#!/usr/bin/env bash
# Script para montar el entorno LXD e instalar RKE2 Server Node de principio a fin.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOG_FILE="rke2_install.log"
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

run_step 01 ../base/check_requisitos.yml "Validar LXD, la red lxdbr0 y la imagen base"
run_step 02 01_crear_vm.yml              "Crear la VM LXD para RKE2 Server Node (2 vCPU, 4GB RAM)"
run_step 03 02_configurar_os.yml         "Configurar sistema operativo y módulos de kernel en la VM"
run_step 04 03_instalar_rke2_server.yml  "Instalar y arrancar RKE2 Server Node (cni: canal)"

SERVER_IP=$(awk '/^rke2-server1/ { for (i=1;i<=NF;i++) if ($i ~ /^ansible_host=/) print substr($i, index($i, "=")+1) }' inventory.ini)

{
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  ¡Clúster RKE2 Server instalado y listo!"
  echo "  "
  echo "  Para conectarte por SSH a la VM:"
  echo "  ssh root@${SERVER_IP}"
  echo "  "
  echo "  Para usar kubectl desde tu host local:"
  echo "  export KUBECONFIG=\$(pwd)/kubeconfig.yaml"
  echo "  kubectl get nodes"
  echo "  "
  echo "  Para destruir el entorno: ./destroy_all.sh"
  echo "════════════════════════════════════════════════════════════════"
} | tee -a "$LOG_FILE"
