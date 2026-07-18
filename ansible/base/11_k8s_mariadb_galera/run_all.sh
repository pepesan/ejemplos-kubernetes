#!/usr/bin/env bash
# Despliega un clúster de MariaDB (Galera) sobre Kubernetes HA con Longhorn y Cilium.
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

run_playbook 01 ../check_requisitos.yml                "Validar LXD, la red y la imagen base"
run_playbook 02 02_crear_nodos.yml                     "Crear las máquinas virtuales LXD para el clúster (3 managers + 3 workers hiperconvergentes)"
run_playbook 03 03_configurar_os.yml                   "Configurar módulos de kernel y sysctl en los nodos"
run_playbook 04 04_instalar_containerd.yml             "Instalar y configurar containerd (CRI) con systemd driver"
run_playbook 05 05_instalar_k8s_tools.yml              "Instalar kubeadm, kubelet y kubectl (hold de versiones)"
run_playbook 06 06_inicializar_primer_manager.yml      "Inicializar el primer manager (kube-vip + Cilium CNI + kubeadm init HA)"
run_playbook 07 07_unir_managers.yml                   "Unir los managers adicionales al plano de control HA"
run_playbook 08 08_unir_workers.yml                    "Unir los nodos workers al clúster (vía el VIP)"
run_playbook 09 09_configurar_cilium_lb.yml            "Configurar el LoadBalancer L2 nativo de Cilium (LB-IPAM + L2Announcement)"
run_playbook 10 10_desplegar_headlamp.yml              "Desplegar Headlamp Dashboard (pronto, para seguir el resto de despliegues desde la consola web)"
run_playbook 11 11_desplegar_longhorn.yml              "Desplegar Longhorn (backend de almacenamiento persistente)"
run_playbook 12 12_desplegar_mariadb_operator.yml      "Desplegar el mariadb-operator"
run_playbook 13 13_desplegar_mariadb_cluster.yml       "Desplegar el clúster MariaDB (Galera)"
run_playbook 14 14_verificar_mariadb.yml               "Verificar la replicación Galera y el acceso externo"

host_ip() { awk -v h="$1" '$1==h { for (i=1;i<=NF;i++) if ($i ~ /^ansible_host=/) print substr($i, index($i, "=")+1) }' inventory.ini; }
VIP=$(awk -F': ' '/^k8s_vip_address:/ { gsub(/"/,"",$2); print $2 }' group_vars/all.yml)
MARIADB_IP=$(kubectl --kubeconfig=kubeconfig.yaml -n mariadb get svc mariadb-galera-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

{
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  Clúster Kubernetes HA con MariaDB (Galera) listo!"
  echo "  VIP del plano de control: ${VIP}:6443"
  echo "  Manager 1: $(host_ip k8s-manager1)"
  echo "  Manager 2: $(host_ip k8s-manager2)"
  echo "  Manager 3: $(host_ip k8s-manager3)"
  echo "  Worker 1:  $(host_ip k8s-worker1)"
  echo "  Worker 2:  $(host_ip k8s-worker2)"
  echo "  Worker 3:  $(host_ip k8s-worker3)"
  echo "  "
  if [ -n "$MARIADB_IP" ]; then
    echo "  MariaDB (IP LB-IPAM de Cilium): ${MARIADB_IP}"
    echo "  Prueba: mysql -h ${MARIADB_IP} -u root -p"
  fi
  if [ -f "mariadb_root_password.txt" ]; then
    echo "  Contraseña root guardada en: $(pwd)/mariadb_root_password.txt"
  fi
  echo "  "
  if [ -f "headlamp_token.txt" ]; then
    echo "  Headlamp Dashboard: http://${VIP}:32082"
    echo "  Token de acceso guardado en: $(pwd)/headlamp_token.txt"
    echo "  "
  fi
  echo "  Panel de Longhorn: http://${VIP}:32085"
  echo "  "
  echo "  Para usar kubectl desde tu host local:"
  echo "  export KUBECONFIG=\$(pwd)/kubeconfig.yaml"
  echo "  kubectl get nodes"
  echo "  "
  echo "  Para destruirlo: ./destroy_all.sh"
  echo "════════════════════════════════════════════════════════════════"
} | tee -a "$LOG_FILE"
