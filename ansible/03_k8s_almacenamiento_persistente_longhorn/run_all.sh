#!/usr/bin/env bash
# Ejecuta todos los playbooks para el clúster de Kubernetes con persistencia Longhorn en LXD.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HASTA="09"
if [ "${1:-}" = "--hasta" ]; then
  HASTA="$2"
fi

LOG_FILE="ansible.log"
# Borrar log al iniciar
rm -f "$LOG_FILE"

run_playbook() {
  local numero="$1"
  local fichero="$2"
  local descripcion="$3"

  if (( 10#$numero > 10#$HASTA )); then
    return
  fi

  echo "" | tee -a "$LOG_FILE"
  echo "════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
  echo "  [$numero] $descripcion" | tee -a "$LOG_FILE"
  echo "════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
  ansible-playbook "$fichero" 2>&1 | tee -a "$LOG_FILE"
}

run_playbook 01 01_check_requisitos.yml     "Validar LXD, la red y la imagen base"
run_playbook 02 02_crear_nodos.yml          "Crear las máquinas virtuales LXD para el clúster"
run_playbook 03 03_configurar_os.yml        "Configurar módulos, sysctl y requisitos de Longhorn (iscsi/nfs)"
run_playbook 04 04_instalar_containerd.yml  "Instalar y configurar containerd (CRI) con systemd driver"
run_playbook 05 05_instalar_k8s_tools.yml   "Instalar kubeadm, kubelet y kubectl (hold de versiones)"
run_playbook 06 06_inicializar_manager.yml  "Inicializar plano de control (Manager) y Flannel"
run_playbook 07 07_unir_workers.yml         "Unir los nodos workers al clúster"
run_playbook 08 08_desplegar_longhorn.yml   "Desplegar Longhorn Engine y Dashboard en Kubernetes"
run_playbook 09 09_verificar_persistencia_rwx.yml "Desplegar PVC y Pods de prueba para verificar persistencia RWX"

{
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  Clúster Kubernetes con Almacenamiento Longhorn listo!"
  echo "  Manager:            10.207.154.50"
  echo "  Workload Worker 1:  10.207.154.51"
  echo "  Workload Worker 2:  10.207.154.52"
  echo "  Storage Worker 1:   10.207.154.56"
  echo "  Storage Worker 2:   10.207.154.57"
  echo "  Storage Worker 3:   10.207.154.58"
  echo "  "
  echo "  Panel de Administración de Longhorn: http://10.207.154.50:32085"
  echo "  "
  echo "  Para usar kubectl desde tu host local:"
  echo "  export KUBECONFIG=\$(pwd)/kubeconfig.yaml"
  echo "  kubectl get nodes"
  echo "  "
  echo "  Para destruirlo: ./destroy_all.sh"
  echo "════════════════════════════════════════════════════════════════"
} | tee -a "$LOG_FILE"
