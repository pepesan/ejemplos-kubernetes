#!/usr/bin/env bash
#
# test_config.sh - Definiciones de matrices de prueba
# Parametrización centralizada para evitar duplicación
#
# Uso: source test_config.sh

# ============================================================================
# MATRIZ MULTIDISTRO: 00_instalar_ansible.sh
# ============================================================================

declare -gA DISTROS=(
  # Ubuntu (LTS + Latest)
  [ubuntu_2404]="ubuntu:24.04"
  [ubuntu_2604]="ubuntu:26.04"

  # Debian (Stable + Testing)
  [debian_12]="debian:12"
  [debian_13]="debian:13"

  # Rocky Linux
  [rocky_9]="rockylinux:9"
  [rocky_10]="rockylinux:10"

  # Fedora (Latest releases)
  [fedora_40]="fedora:40"
  [fedora_41]="fedora:41"

  # openSUSE (Stable + Rolling)
  [opensuse_leap]="opensuse/leap:16.0"
  [opensuse_tumbleweed]="opensuse/tumbleweed:latest"
)

# Distros a probar (subset si no quieres todas)
ENABLED_DISTROS=(
  ubuntu_2404
  ubuntu_2604
  debian_12
  debian_13
  rocky_9
  rocky_10
  fedora_40
  fedora_41
  opensuse_leap
  opensuse_tumbleweed
)

# ============================================================================
# MATRIZ DE LABS: Revalidaciones de idempotencia
# ============================================================================

declare -gA LABS=(
  # Formato: [numero]="nombre_descriptivo"
  [01]="k8s_base_un_nodo"
  [02]="k8s_base_ha_3_managers_3_workers"
  [03]="k8s_ha_almacenamiento_persistente_longhorn"
  [04]="k8s_ha_almacenamiento_persistente_rook_ceph"
  [05]="k8s_ha_almacenamiento_persistente_externo_ceph"
  [06]="k8s_red_ingress_metallb"
  [07]="k8s_observabilidad_loki_grafana_prometheus"
  [08]="k8s_gateway_api"
  [09]="k8s_actualizacion_cluster_ha"
  [10]="k8s_percona_mysql_pxc"
  [11]="k8s_mariadb_galera"
  [12]="k8s_percona_postgresql"
  [13]="k8s_percona_mongodb"
  [14]="k8s_vault_secretos_bbdd"
)

# Labs a revalidar (subset si no quieres todos)
ENABLED_LABS=(
  02  # Base HA (crítico, heredado por todos)
  03  # Longhorn (heredado por 07-14)
  04  # Rook Ceph (cambios en chart_version)
  06  # MetalLB + Ingress
  08  # Gateway API (cambios en imágenes)
)

# ============================================================================
# CAMBIOS EN ESTE CICLO (2026-08-09)
# ============================================================================

# Variables parametrizadas (simplifica tracking de cambios)
declare -gA CHANGED_VARS=(
  # Lab 04: Nueva variable de chart
  [rook_ceph_chart_version]="1.14.7"

  # Imágenes de test actualizadas (evitar 'latest')
  [test_nginx_image]="nginx:1.31-alpine"
  [test_alpine_image]="alpine:3.21"
  [test_busybox_image]="busybox:1.36.1"
  [grpc_demo_image]="kong/grpcbin:0.5"
)

# Labs que recibieron cambios
declare -gA LABS_WITH_CHANGES=(
  [01]="test_nginx_image, test_alpine_image"
  [02]="test_nginx_image, test_alpine_image"
  [03]="test_alpine_image"
  [04]="rook_ceph_chart_version, test_alpine_image"
  [05]="test_alpine_image"
  [06]="test_nginx_image, test_busybox_image"
  [08]="test_nginx_image, grpc_demo_image"
)

# ============================================================================
# CRITERIOS DE ÉXITO
# ============================================================================

# Para multidistro: todas estas condiciones deben cumplirse
MULTIDISTRO_SUCCESS_CRITERIA=(
  "exit_code:0"           # Script debe terminar sin error
  "ansible:installed"     # ansible-playbook disponible
  "kubectl:installed"     # kubectl disponible
  "helm:installed"        # helm disponible
  "duration:<600"         # < 10 minutos
)

# Para labs: idempotencia comprobada
LAB_SUCCESS_CRITERIA=(
  "pass1:exit:0"          # Pasada 1 exit 0
  "pass2:exit:0"          # Pasada 2 exit 0
  "pass2:changed:<5"      # Pasada 2 cambios mínimos (idempotencia)
  "cleanup:exit:0"        # Cleanup exit 0
)

# ============================================================================
# UTILIDADES DE CONFIGURACIÓN
# ============================================================================

# Obtener ruta base del lab
get_lab_path() {
  local lab_num="$1"
  local lab_name="${LABS[$lab_num]}"
  echo "$(dirname "${BASH_SOURCE[0]}")/${lab_num}_${lab_name}"
}

# Obtener lista de distros habilitadas
get_enabled_distros() {
  printf '%s\n' "${ENABLED_DISTROS[@]}"
}

# Obtener lista de labs habilitados
get_enabled_labs() {
  printf '%s\n' "${ENABLED_LABS[@]}"
}

# Obtener cambios específicos de un lab
get_lab_changes() {
  local lab_num="$1"
  echo "${LABS_WITH_CHANGES[$lab_num]:-}"
}

# Exportar para uso en subshells
export DISTROS ENABLED_DISTROS LABS ENABLED_LABS CHANGED_VARS LABS_WITH_CHANGES
export MULTIDISTRO_SUCCESS_CRITERIA LAB_SUCCESS_CRITERIA

# Info si se ejecuta directamente
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
  echo "📋 Configuración de Matrices de Prueba"
  echo ""
  echo "Distros habilitadas ($(printf '%s\n' "${ENABLED_DISTROS[@]}" | wc -l)):"
  printf '%s\n' "${ENABLED_DISTROS[@]}" | sed 's/^/  - /'
  echo ""
  echo "Labs habilitados ($(printf '%s\n' "${ENABLED_LABS[@]}" | wc -l)):"
  printf '%s\n' "${ENABLED_LABS[@]}" | sed 's/^/  - Lab /'
  echo ""
  echo "Variables cambiadas:"
  for var in "${!CHANGED_VARS[@]}"; do
    echo "  - $var=${CHANGED_VARS[$var]}"
  done
fi
