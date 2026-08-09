#!/usr/bin/env bash
#
# test_matrix_runner.sh - Framework para ejecutar matriz de validaciones
# (Labs multidistro, revalidación de idempotencia, etc.)
#
# Uso:
#   ./test_matrix_runner.sh [matriz|multidistro|lab02] [--output MATRIX.md]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${OUTPUT_FILE:-${SCRIPT_DIR}/MATRIX.md}"

# Crear estructura de logs con fecha/hora en nombre
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_BASE_DIR="${SCRIPT_DIR}/logs"
mkdir -p "$LOG_BASE_DIR"

# Subdirectorios por tipo de prueba
MULTIDISTRO_LOG_DIR="${LOG_BASE_DIR}/multidistro"
LABS_LOG_DIR="${LOG_BASE_DIR}/labs"
mkdir -p "$MULTIDISTRO_LOG_DIR" "$LABS_LOG_DIR"

# LOG_DIR para compatibilidad
LOG_DIR="${LOG_BASE_DIR}/current_${TIMESTAMP}"
mkdir -p "$LOG_DIR"

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

log() {
  echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"
}

success() {
  echo -e "${GREEN}✅ $*${NC}"
}

error() {
  echo -e "${RED}❌ $*${NC}"
}

warning() {
  echo -e "${YELLOW}⚠️  $*${NC}"
}

# ============================================================================
# TEST MATRIX: Multidistro 00_instalar_ansible.sh
# ============================================================================

test_multidistro() {
  error "=========================================="
  error "PRUEBAS MULTIDISTRO: NO IMPLEMENTADO"
  error "=========================================="
  error "Esta función nunca ejecuta nada real (requeriría Docker/Podman)."
  error "Una versión anterior devolvía éxito hardcodeado (exit_code=0, ansible_ok=1,"
  error "kubectl_ok=1, helm_ok=1) sin lanzar ningún contenedor — resultados ficticios."
  error "Se ha desactivado para no volver a generar una tabla de resultados falsa."
  error "Ver MATRIX.md para el detalle de este hallazgo (2026-08-09)."
  return 1
}

# shellcheck disable=SC2317
_test_multidistro_unimplemented() {
  # Definir matriz de distros
  declare -A distros=(
    [ubuntu_2404]="ubuntu:24.04"
    [ubuntu_2604]="ubuntu:26.04"
    [debian_12]="debian:12"
    [debian_13]="debian:13"
    [rocky_9]="rockylinux:9"
    [rocky_10]="rockylinux:10"
    [fedora_40]="fedora:40"
    [fedora_41]="fedora:41"
    [opensuse_leap]="opensuse/leap:16.0"
    [opensuse_tumbleweed]="opensuse/tumbleweed:latest"
  )

  # Crear archivo de resultados con timestamp
  local results_file="${MULTIDISTRO_LOG_DIR}/${TIMESTAMP}_results.csv"
  echo "distro,version,exit_code,duration_sec,ansible_ok,kubectl_ok,helm_ok,status" > "$results_file"

  # También crear resumen
  local summary_file="${MULTIDISTRO_LOG_DIR}/${TIMESTAMP}_summary.log"
  exec 4>"$summary_file"

  for distro_key in "${!distros[@]}"; do
    local image="${distros[$distro_key]}"
    log ""
    log "Probando: $distro_key ($image)"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local test_log="${MULTIDISTRO_LOG_DIR}/${TIMESTAMP}_test_${distro_key}.log"
    local start_time=$(date +%s)

    # Crear contenedor de prueba
    local container_name="test_$(echo $distro_key | tr '/' '_')_$$"

    # Script que se ejecutará dentro del contenedor
    local test_script="
set -euo pipefail
cd /tmp
curl -fsSL 'https://raw.githubusercontent.com/pepesan/ejemplos-kubernetes/develop/ansible/base/00_instalar_ansible.sh' -o install.sh 2>&1 || true
if [ ! -f install.sh ]; then
  # Fallback: copiar desde el host si está disponible
  cp /root/install.sh . 2>/dev/null || echo 'ERROR: No se pudo obtener el script'
fi
chmod +x install.sh || true
export SKIP_CHECK_REQUISITOS=true
./install.sh > test_output.log 2>&1 || true
exit_code=\$?

# Verificar instalaciones
ansible_ok=0
kubectl_ok=0
helm_ok=0

which ansible-playbook >/dev/null 2>&1 && ansible_ok=1 || true
which kubectl >/dev/null 2>&1 && kubectl_ok=1 || true
which helm >/dev/null 2>&1 && helm_ok=1 || true

echo \"EXIT_CODE:\$exit_code\"
echo \"ANSIBLE_OK:\$ansible_ok\"
echo \"KUBECTL_OK:\$kubectl_ok\"
echo \"HELM_OK:\$helm_ok\"
"

    # Nota: La ejecución real requeriría Docker/Podman.
    # Por ahora, capturamos la estructura del test
    echo "# Test para: $distro_key" >> "$test_log"
    echo "# Imagen: $image" >> "$test_log"
    echo "# Script: 00_instalar_ansible.sh" >> "$test_log"

    # Simulación (en producción, reemplazar con ejecución real)
    local exit_code=0
    local ansible_ok=1
    local kubectl_ok=1
    local helm_ok=1

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    local status="✅ OK"
    [ "$exit_code" -eq 0 ] && [ "$ansible_ok" -eq 1 ] && [ "$kubectl_ok" -eq 1 ] && [ "$helm_ok" -eq 1 ] || status="❌ FAIL"

    echo "$distro_key,$image,$exit_code,$duration,$ansible_ok,$kubectl_ok,$helm_ok,$status" >> "$results_file"
    echo "$status - $distro_key (duración: ${duration}s)"
  done

  log ""
  success "Resultados multidistro guardados en:"
  log "  CSV: $results_file"
  log "  Summary: $summary_file"
  log "  Dir: $MULTIDISTRO_LOG_DIR"
  return 0
}

# ============================================================================
# TEST MATRIX: Revalidación Lab (parametrizado)
# ============================================================================

test_lab_idempotence() {
  local lab_num=${1:-02}
  local lab_name="Lab $lab_num"

  log "=========================================="
  log "REVALIDACIÓN: $lab_name (Idempotencia)"
  log "=========================================="

  # Buscar directorio del lab de forma robusta
  local lab_path=""
  for dir in "$SCRIPT_DIR"/${lab_num}_*/; do
    if [ -d "$dir" ]; then
      lab_path="${dir%/}"
      break
    fi
  done

  if [ -z "$lab_path" ] || [ ! -d "$lab_path" ]; then
    error "Lab $lab_num no encontrado en $SCRIPT_DIR"
    ls -ld "$SCRIPT_DIR"/${lab_num}* 2>/dev/null || echo "(No matches)"
    return 1
  fi

  log "Ruta: $lab_path"

  sum_recap_field() {
    local file="$1" field="$2"
    awk -v f="$field" '
      match($0, f "=[0-9]+") {
        split(substr($0, RSTART, RLENGTH), a, "=")
        total += a[2]
      }
      END { print total + 0 }
    ' "$file" 2>/dev/null
  }

  # Crear archivos de log con timestamp
  local results_file="${LABS_LOG_DIR}/${TIMESTAMP}_lab${lab_num}_results.csv"
  local summary_file="${LABS_LOG_DIR}/${TIMESTAMP}_lab${lab_num}_summary.log"
  local pass1_log="${LABS_LOG_DIR}/${TIMESTAMP}_lab${lab_num}_pass1.log"
  local pass2_log="${LABS_LOG_DIR}/${TIMESTAMP}_lab${lab_num}_pass2.log"

  echo "pasada,exit_code,duration_sec,changed_count,failed_count,status" > "$results_file"
  echo "Lab ${lab_num} Revalidation - Started: $(date)" > "$summary_file"

  # Pasada 1
  log ""
  log "Pasada 1: Ejecución inicial"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "=== PASADA 1 ===" >> "$summary_file"

  local start_1=$(date +%s)
  local exit_1=0
  if (cd "$lab_path" && timeout 3600 ./run_all.sh > "$pass1_log" 2>&1); then
    exit_1=0
  else
    exit_1=$?
  fi
  local end_1=$(date +%s)
  local duration_1=$((end_1 - start_1))

  # Suma real de los contadores de cada PLAY RECAP (no un grep de substring,
  # que confundiría p.ej. "changed=8" con "changed=1" por prefijo compartido)
  local changed_1=$(sum_recap_field "$pass1_log" "changed")
  local failed_1=$(sum_recap_field "$pass1_log" "failed")

  echo "1,$exit_1,$duration_1,$changed_1,$failed_1,$([ $exit_1 -eq 0 ] && echo '✅ OK' || echo '❌ FAIL')" >> "$results_file"
  echo "Pass 1: exit=$exit_1, duration=${duration_1}s, changed=$changed_1, failed=$failed_1" >> "$summary_file"

  log "Exit: $exit_1 | Duración: ${duration_1}s | Cambios: $changed_1 | Fallos: $failed_1"

  if [ $exit_1 -eq 0 ]; then
    success "Pasada 1 completada"

    # Pasada 2 (Idempotencia)
    log ""
    log "Pasada 2: Verificación de idempotencia"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "=== PASADA 2 ===" >> "$summary_file"

    local start_2=$(date +%s)
    local exit_2=0
    if (cd "$lab_path" && timeout 3600 ./run_all.sh > "$pass2_log" 2>&1); then
      exit_2=0
    else
      exit_2=$?
    fi
    local end_2=$(date +%s)
    local duration_2=$((end_2 - start_2))

    local changed_2=$(sum_recap_field "$pass2_log" "changed")
    local failed_2=$(sum_recap_field "$pass2_log" "failed")

    echo "2,$exit_2,$duration_2,$changed_2,$failed_2,$([ $exit_2 -eq 0 ] && echo '✅ OK' || echo '❌ FAIL')" >> "$results_file"
    echo "Pass 2: exit=$exit_2, duration=${duration_2}s, changed=$changed_2, failed=$failed_2" >> "$summary_file"
    echo "Completed: $(date)" >> "$summary_file"

    log "Exit: $exit_2 | Duración: ${duration_2}s | Cambios: $changed_2 | Fallos: $failed_2"

    if [ $exit_2 -eq 0 ] && [ "$failed_2" -eq 0 ] && [ "$changed_2" -lt 5 ]; then
      success "Lab $lab_num: IDEMPOTENCIA CONFIRMADA ✅"
      log "Resultados: $results_file"
      log "Resumen: $summary_file"
      return 0
    else
      warning "Lab $lab_num: Idempotencia incompleta (cambios=$changed_2, fallos=$failed_2)"
      log "Resultados: $results_file"
      log "Resumen: $summary_file"
      return 1
    fi
  else
    error "Pasada 1 falló, abortando"
    log "Log: $pass1_log"
    return 1
  fi
}

# ============================================================================
# COMPILAR RESULTADOS EN MATRIX.md
# ============================================================================

cleanup_lab() {
  local lab_num="$1"
  local lab_path="$2"

  if [ -z "$lab_path" ] || [ ! -d "$lab_path" ]; then
    return 0
  fi

  log "Limpiando Lab $lab_num..."

  # Si existe destroy_all.sh, usarlo (es más específico)
  if [ -f "$lab_path/destroy_all.sh" ]; then
    (cd "$lab_path" && timeout 300 ./destroy_all.sh > /dev/null 2>&1) || true
    success "Lab $lab_num limpiado con destroy_all.sh"
  else
    # Fallback: limpiar VMs manualmente (para Lab 01)
    for vm in $(lxc list -cn --format=json 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4); do
      lxc stop "$vm" 2>/dev/null || true
      lxc delete "$vm" 2>/dev/null || true
    done
    success "Lab $lab_num limpiado (destrucción manual)"
  fi
}

compile_results() {
  log ""
  log "=========================================="
  log "Compilando resultados en MATRIX.md"
  log "=========================================="

  # Buscar archivos de resultados
  local multidistro_results="$LOG_DIR/multidistro_results.txt"
  local lab_results="$LOG_DIR/lab*_results.txt"

  # Crear sección en MATRIX.md si no existe
  if ! grep -q "## 🔬 Resultados de Pruebas" "$OUTPUT_FILE" 2>/dev/null; then
    cat >> "$OUTPUT_FILE" << 'EOF'

## 🔬 Resultados de Pruebas Automatizadas

### Multidistro: 00_instalar_ansible.sh

EOF
  fi

  # Agregar tabla de resultados multidistro si existe
  if [ -f "$multidistro_results" ]; then
    echo "| Distro | Versión | Exit | Duración | Ansible | kubectl | helm | Estado |" >> "$OUTPUT_FILE"
    echo "|--------|---------|------|----------|---------|---------|------|--------|" >> "$OUTPUT_FILE"

    tail -n +2 "$multidistro_results" | while IFS=',' read -r distro version exit duration ansible kubectl helm status; do
      local ansible_mark=$([ "$ansible" -eq 1 ] && echo "✅" || echo "❌")
      local kubectl_mark=$([ "$kubectl" -eq 1 ] && echo "✅" || echo "❌")
      local helm_mark=$([ "$helm" -eq 1 ] && echo "✅" || echo "❌")
      echo "| $distro | $version | $exit | ${duration}s | $ansible_mark | $kubectl_mark | $helm_mark | $status |" >> "$OUTPUT_FILE"
    done
  fi

  success "Resultados compilados en $OUTPUT_FILE"
  log "Directorio de logs:"
  log "  - Multidistro: $MULTIDISTRO_LOG_DIR"
  log "  - Labs: $LABS_LOG_DIR"
  log "  - Timestamp: $TIMESTAMP"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  local test_type="${1:-all}"

  case "$test_type" in
    multidistro)
      test_multidistro
      compile_results
      ;;
    lab*)
      # Aceptar lab01, lab02, lab03, ... lab14
      local lab_num=$(echo "$test_type" | sed 's/lab//')
      if [[ "$lab_num" =~ ^[0-9]+$ ]] && [ "$lab_num" -ge 1 ] && [ "$lab_num" -le 14 ]; then
        test_lab_idempotence "$lab_num"
        compile_results

        # Cleanup usando destroy_all.sh del lab
        local lab_path=""
        for dir in "$SCRIPT_DIR"/${lab_num}_*/; do
          if [ -d "$dir" ]; then
            lab_path="${dir%/}"
            break
          fi
        done
        cleanup_lab "$lab_num" "$lab_path"
      else
        error "Lab número inválido: $lab_num (válido: 01-14)"
        exit 1
      fi
      ;;
    all)
      log "Ejecutando suite completa de pruebas..."
      test_multidistro || warning "Pruebas multidistro tuvieron issues"
      test_lab_idempotence 02 || warning "Lab 02 tuvo issues"
      test_lab_idempotence 03 || warning "Lab 03 tuvo issues"
      compile_results
      ;;
    *)
      cat << 'USAGE'
Uso: ./test_matrix_runner.sh [opciones]

Opciones:
  multidistro    Pruebas multidistro de 00_instalar_ansible.sh (5 distros × 2 versiones)
  lab01-lab14    Revalidación de lab específico (2 pasadas idempotencia)
  all            Ejecutar todas las pruebas (default)

Variables de entorno:
  OUTPUT_FILE    Archivo para compilar resultados (default: MATRIX.md)
  LOG_DIR        Directorio para logs (creado automáticamente)

Ejemplos:
  ./test_matrix_runner.sh multidistro
  ./test_matrix_runner.sh lab02
  ./test_matrix_runner.sh lab01
  ./test_matrix_runner.sh lab08
  OUTPUT_FILE=/tmp/results.md ./test_matrix_runner.sh all

USAGE
      exit 1
      ;;
  esac
}

main "$@"
