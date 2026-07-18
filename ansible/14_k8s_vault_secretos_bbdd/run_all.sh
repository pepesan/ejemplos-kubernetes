#!/usr/bin/env bash
# Despliega HashiCorp Vault (HA, Raft) con secretos dinámicos de MySQL/PXC sobre Kubernetes HA con Longhorn y Cilium.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# A diferencia de los escenarios 10-13 (donde el flujo por defecto se
# detiene en el paso de "verificación" y deja el escalado/upgrade como
# extras manuales), aquí llega HASTA el paso 20 inclusive por defecto: la
# demostración completa de la credencial dinámica (generación, uso y
# revocación automática) ES el objetivo pedagógico central del
# laboratorio, no un extra opcional.
HASTA="21"
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
run_playbook 12 12_desplegar_percona_operator.yml      "Desplegar el Percona Operator for MySQL (PXC)"
run_playbook 13 13_desplegar_pxc_cluster.yml           "Desplegar el clúster Percona XtraDB Cluster (Galera) — la BBDD objetivo de Vault"
run_playbook 14 14_verificar_pxc.yml                   "Verificar la replicación Galera y el acceso externo"
run_playbook 15 15_instalar_csi_driver.yml             "Instalar el Secrets Store CSI Driver"
run_playbook 16 16_desplegar_vault.yml                 "Desplegar HashiCorp Vault en modo HA (Raft) + CSI Provider"
run_playbook 17 17_inicializar_vault.yml               "Inicializar y desellar Vault (claves Shamir)"
run_playbook 18 18_secretos_estaticos_kv.yml           "Configurar y probar el motor KV de secretos estáticos (el uso más básico y estándar de Vault)"
run_playbook 19 19_configurar_vault_k8s_auth.yml       "Configurar la autenticación Kubernetes de Vault y su policy"
run_playbook 20 20_configurar_motor_secretos_bbdd.yml  "Configurar el Database Secrets Engine de Vault (MySQL/PXC)"
run_playbook 21 21_desplegar_app_demo.yml              "Desplegar la app de ejemplo y verificar el ciclo de vida completo de la credencial dinámica"

host_ip() { awk -v h="$1" '$1==h { for (i=1;i<=NF;i++) if ($i ~ /^ansible_host=/) print substr($i, index($i, "=")+1) }' inventory.ini; }
VIP=$(awk -F': ' '/^k8s_vip_address:/ { gsub(/"/,"",$2); print $2 }' group_vars/all.yml)
PXC_IP=$(kubectl --kubeconfig=kubeconfig.yaml -n pxc get svc pxc-db-haproxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

{
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  Clúster Kubernetes HA con HashiCorp Vault (secretos dinámicos) listo!"
  echo "  VIP del plano de control: ${VIP}:6443"
  echo "  Manager 1: $(host_ip k8s-manager1)"
  echo "  Manager 2: $(host_ip k8s-manager2)"
  echo "  Manager 3: $(host_ip k8s-manager3)"
  echo "  Worker 1:  $(host_ip k8s-worker1)"
  echo "  Worker 2:  $(host_ip k8s-worker2)"
  echo "  Worker 3:  $(host_ip k8s-worker3)"
  echo "  "
  if [ -n "$PXC_IP" ]; then
    echo "  PXC (IP LB-IPAM de Cilium): ${PXC_IP}"
    echo "  Prueba: mysql -h ${PXC_IP} -u root -p"
  fi
  if [ -f "pxc_root_password.txt" ]; then
    echo "  Contraseña root de PXC guardada en: $(pwd)/pxc_root_password.txt"
  fi
  echo "  "
  if [ -f "vault_credentials.json" ]; then
    echo "  Claves de unseal + token root de Vault guardados en: $(pwd)/vault_credentials.json"
    echo "  export KUBECONFIG=\$(pwd)/kubeconfig.yaml"
    echo "  kubectl -n vault exec -it vault-0 -- vault status"
  fi
  echo "  "
  if [ -f "headlamp_token.txt" ]; then
    echo "  Headlamp Dashboard: http://${VIP}:32082"
    echo "  Token de acceso guardado en: $(pwd)/headlamp_token.txt"
    echo "  "
  fi
  echo "  Panel de Longhorn: http://${VIP}:32085"
  echo "  "
  echo "  Para destruirlo: ./destroy_all.sh"
  echo "════════════════════════════════════════════════════════════════"
} | tee -a "$LOG_FILE"
