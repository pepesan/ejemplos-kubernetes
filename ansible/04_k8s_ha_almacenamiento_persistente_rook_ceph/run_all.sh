#!/usr/bin/env bash
# Ejecuta todos los playbooks para el clúster de Kubernetes HA en LXD.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HASTA="14"
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

run_playbook 01 ../check_requisitos.yml             "Validar LXD, la red y la imagen base"
run_playbook 02 02_crear_nodos.yml                  "Crear las máquinas virtuales LXD para el clúster (3 managers + 3 workers)"
run_playbook 03 03_configurar_os.yml                "Configurar módulos de kernel y sysctl en los nodos"
run_playbook 04 04_instalar_containerd.yml          "Instalar y configurar containerd (CRI) con systemd driver"
run_playbook 05 05_instalar_k8s_tools.yml           "Instalar kubeadm, kubelet y kubectl (hold de versiones)"
run_playbook 06 06_inicializar_primer_manager.yml   "Inicializar el primer manager (kube-vip + kubeadm init HA)"
run_playbook 07 07_unir_managers.yml                "Unir los managers adicionales al plano de control HA"
run_playbook 08 08_unir_workers.yml                 "Unir los nodos workers al clúster (vía el VIP)"
run_playbook 09 09_desplegar_rook_ceph.yml          "Desplegar el operador y clúster de Rook Ceph"
run_playbook 10 10_verificar_rook_persistencia.yml  "Verificar persistencia con volúmenes RBD y CephFS"
run_playbook 11 11_desplegar_prometheus.yml         "Desplegar Prometheus y conectarlo al Ceph Dashboard"
run_playbook 12 12_desplegar_headlamp.yml           "Desplegar Headlamp Dashboard"


host_ip() { awk -v h="$1" '$1==h { for (i=1;i<=NF;i++) if ($i ~ /^ansible_host=/) print substr($i, index($i, "=")+1) }' inventory.ini; }
VIP=$(awk -F': ' '/^k8s_vip_address:/ { gsub(/"/,"",$2); print $2 }' group_vars/all.yml)

{
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  Clúster Kubernetes HA con Almacenamiento Rook Ceph listo!"
  echo "  VIP del plano de control: ${VIP}:6443"
  echo "  Manager 1: $(host_ip k8s-manager1)"
  echo "  Manager 2: $(host_ip k8s-manager2)"
  echo "  Manager 3: $(host_ip k8s-manager3)"
  echo "  Worker 1:  $(host_ip k8s-worker1) (con OSD)"
  echo "  Worker 2:  $(host_ip k8s-worker2) (con OSD)"
  echo "  Worker 3:  $(host_ip k8s-worker3) (con OSD)"
  echo "  "
  if [ -f "headlamp_token.txt" ]; then
    echo "  Headlamp Dashboard: http://${VIP}:32082"
    echo "  Token de acceso guardado en: $(pwd)/headlamp_token.txt"
    echo "  "
  fi
  if [ -f "ceph_dashboard_password.txt" ]; then
    echo "  Ceph Dashboard:     http://${VIP}:32070"
    echo "  Usuario Ceph:       admin"
    echo "  Contraseña guardada en: $(pwd)/ceph_dashboard_password.txt"
    echo "  "
  fi
  echo "  Para usar kubectl desde tu host local:"
  echo "  export KUBECONFIG=\$(pwd)/kubeconfig.yaml"
  echo "  kubectl get nodes"
  echo "  "
  echo "  Para destruirlo: ./destroy_all.sh"
  echo "════════════════════════════════════════════════════════════════"
} | tee -a "$LOG_FILE"
