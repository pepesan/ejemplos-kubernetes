#!/usr/bin/env bash
# Ejecuta todos los playbooks para el nodo único de Kubernetes en LXD.
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

run_playbook 01 ../check_requisitos.yml     "Validar LXD, la red y la imagen base"
run_playbook 02 02_crear_nodo.yml          "Crear el contenedor LXD para Kubernetes con recursos"
run_playbook 03 03_configurar_os.yml       "Configurar módulos de kernel y sysctl en el contenedor"
run_playbook 04 04_instalar_containerd.yml "Instalar y configurar containerd (CRI) con systemd driver"
run_playbook 05 05_instalar_k8s_tools.yml  "Instalar kubeadm, kubelet y kubectl (hold de versiones)"
run_playbook 06 06_inicializar_cluster.yml "Inicializar clúster, instalar Flannel y quitar Taint"
run_playbook 07 07_desplegar_headlamp.yml   "Desplegar Headlamp Dashboard y configurar acceso (pronto, para seguir el resto desde la consola web)"
run_playbook 08 08_desplegar_nginx.yml      "Desplegar un contenedor Nginx y verificar NodePort"
run_playbook 09 09_despliegue_helm.yml      "Realizar un despliegue de Helm con Apache y verificar"

NODE_IP=$(awk '/^k8s-single/ { for (i=1;i<=NF;i++) if ($i ~ /^ansible_host=/) print substr($i, index($i, "=")+1) }' inventory.ini)

{
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  Nodo Kubernetes listo. Para conectarte por SSH:"
  echo "  ssh root@${NODE_IP}"
  echo "  "
  echo "  Para usar kubectl desde tu host local:"
  echo "  export KUBECONFIG=\$(pwd)/kubeconfig.yaml"
  echo "  kubectl get nodes"
  echo "  "
  echo "  Para destruirlo: ./destroy_all.sh"
  echo "════════════════════════════════════════════════════════════════"
} | tee -a "$LOG_FILE"
