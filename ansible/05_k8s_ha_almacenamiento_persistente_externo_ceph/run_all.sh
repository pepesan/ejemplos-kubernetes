#!/usr/bin/env bash
# Ejecuta todos los playbooks para el clúster de Kubernetes HA y Ceph Externo en LXD.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HASTA="12"
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

run_playbook 01 ../check_requisitos.yml           "Validar LXD, la red y la imagen base"
run_playbook 02 02_crear_nodos.yml                "Crear las máquinas virtuales LXD para el clúster (3 managers + 3 workers + Ceph externo)"
run_playbook 03 03_configurar_os.yml              "Configurar módulos de kernel y sysctl en todos los nodos"
run_playbook 04 04_instalar_containerd.yml        "Instalar y configurar containerd (CRI) con systemd"
run_playbook 05 05_instalar_k8s_tools.yml         "Instalar kubeadm, kubelet y kubectl (hold de versiones)"
run_playbook 06 06_inicializar_primer_manager.yml "Inicializar el primer manager (kube-vip + kubeadm init HA)"
run_playbook 07 07_unir_managers.yml              "Unir los managers adicionales al plano de control HA"
run_playbook 08 08_unir_workers.yml               "Unir los nodos workers al clúster (vía el VIP)"
run_playbook 09 09_desplegar_ceph_externo.yml     "Desplegar el clúster Ceph Externo dedicado"
run_playbook 10 10_integrar_k8s_ceph_externo.yml  "Integrar Ceph en K8s con Ceph CSI Drivers"
run_playbook 11 11_verificar_persistencia.yml     "Verificar persistencia con volúmenes RBD externos"
run_playbook 12 12_desplegar_headlamp.yml         "Desplegar Headlamp Dashboard"

host_ip() { awk -v h="$1" '$1==h { for (i=1;i<=NF;i++) if ($i ~ /^ansible_host=/) print substr($i, index($i, "=")+1) }' inventory.ini; }
VIP=$(awk -F': ' '/^k8s_vip_address:/ { gsub(/"/,"",$2); print $2 }' group_vars/all.yml)

{
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  Clúster Kubernetes HA con Ceph Externo listo!"
  echo "  VIP del plano de control: ${VIP}:6443"
  echo "  Manager 1: $(host_ip k8s-manager1)"
  echo "  Manager 2: $(host_ip k8s-manager2)"
  echo "  Manager 3: $(host_ip k8s-manager3)"
  echo "  Worker 1:  $(host_ip k8s-worker1)"
  echo "  Worker 2:  $(host_ip k8s-worker2)"
  echo "  Worker 3:  $(host_ip k8s-worker3)"
  echo "  Ceph Mon:  $(host_ip ceph-mon)"
  echo "  Ceph OSDs: ceph-osd1, ceph-osd2, ceph-osd3"
  echo "  "
  if [ -f "headlamp_token.txt" ]; then
    echo "  Headlamp Dashboard: http://${VIP}:32082"
    echo "  Token de acceso guardado en: $(pwd)/headlamp_token.txt"
    echo "  "
  fi
  echo "  Ceph Dashboard:     http://$(host_ip ceph-mon):8443 (o puerto por defecto)"
  echo "  Usuario Ceph:       admin"
  if [ -f "ceph_dashboard_password.txt" ]; then
    echo "  Contraseña guardada en: $(pwd)/ceph_dashboard_password.txt"
  fi
  echo "  "
  echo "  Para usar kubectl desde tu host local:"
  echo "  export KUBECONFIG=\$(pwd)/kubeconfig.yaml"
  echo "  kubectl get nodes"
  echo "  "
  echo "  Para destruirlo: ./destroy_all.sh"
  echo "════════════════════════════════════════════════════════════════"
} | tee -a "$LOG_FILE"
