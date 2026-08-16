#!/usr/bin/env bash
# Levanta una VM LXD desechable de una distro concreta, lista para probar
# a mano (interactivamente) el flujo completo de ansible/base:
# 00_instalar_ansible.sh -> 01_bootstrap_host.sh -> 00_bootstrap_host_lxd.yml
# -> check_requisitos.yml.
#
# A diferencia de test_instalar_ansible_distros.sh (contenedores, root,
# SKIP_CHECK_REQUISITOS=true, solo prueba el instalador de Ansible/kubectl/
# helm), este script crea siempre una VM -- el bootstrap real de LXD anidado
# (módulos de kernel overlay/br_netfilter, snap install lxd, lxd init) y la
# descarga de la imagen VM "k8s-template" necesitan una VM, no un contenedor
# -- con un usuario no-root con sudo (como se usaría en la máquina real de un
# alumno), y deja los 5 scripts base copiados y listos para ejecutar a mano.
#
# Uso: manual_test_instance.sh <distro> [nombre-instancia] [--force]
#   distro: una de las claves de DISTRO_IMAGES (ver abajo)
#   nombre-instancia: por defecto "manual-<distro>"
#   --force: si la instancia ya existe, la borra y la vuelve a crear
#            (si no, el script falla para no destruir una VM en uso)
#
# rocky-10 requiere la imagen local "rockylinux/10/vm" -- no hay imagen VM
# publicada todavía (ver ansible/scripts/build_rocky10_lxd_image.sh). Si no
# existe, el script falla con un mensaje explicando cómo construirla.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/../base"

declare -A DISTRO_IMAGES=(
  [ubuntu-2404]="ubuntu:24.04"
  [ubuntu-2604]="ubuntu:26.04"
  [debian-12]="images:debian/12"
  [debian-13]="images:debian/13"
  [rocky-9]="images:rockylinux/9"
  [rocky-10]="rockylinux/10/vm"
  [fedora-43]="images:fedora/43"
  [fedora-44]="images:fedora/44"
  [opensuse-16]="images:opensuse/16.0"
  [opensuse-tumbleweed]="images:opensuse/tumbleweed"
)

usage() {
  echo "Uso: $0 <distro> [nombre-instancia] [--force]"
  echo ""
  echo "Distros disponibles:"
  for d in "${!DISTRO_IMAGES[@]}"; do
    echo "  - $d (${DISTRO_IMAGES[$d]})"
  done | sort
  exit 1
}

[ $# -ge 1 ] || usage
DISTRO="$1"
shift

NAME=""
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    *) NAME="$arg" ;;
  esac
done
NAME="${NAME:-manual-${DISTRO}}"

IMAGE="${DISTRO_IMAGES[$DISTRO]:-}"
if [ -z "$IMAGE" ]; then
  echo "ERROR: distro desconocida '$DISTRO'."
  echo ""
  usage
fi

if [ "$DISTRO" = "rocky-10" ] && ! lxc image info "$IMAGE" &>/dev/null; then
  echo "ERROR: no existe la imagen local '$IMAGE'."
  echo "Constrúyela primero con:"
  echo "  $SCRIPT_DIR/build_rocky10_lxd_image.sh x86_64 vm"
  exit 1
fi

if lxc info "$NAME" &>/dev/null; then
  if [ "$FORCE" = true ]; then
    echo "Instancia '$NAME' ya existe, borrándola (--force)..."
    lxc delete -f "$NAME"
  else
    echo "ERROR: la instancia '$NAME' ya existe. Bórrala a mano o usa --force."
    exit 1
  fi
fi

echo "════════════════════════════════════════════════════════════════"
echo "  Lanzando VM '$NAME' ($IMAGE)"
echo "════════════════════════════════════════════════════════════════"
lxc launch "$IMAGE" "$NAME" --vm -c limits.cpu=4 -c limits.memory=16GiB -d root,size=20GiB

echo "Esperando a que la VM esté lista..."
ready=false
for _ in $(seq 1 30); do
  if lxc exec "$NAME" -- true &>/dev/null; then
    ready=true
    break
  fi
  sleep 2
done
if [ "$ready" != true ]; then
  echo "ERROR: la VM '$NAME' no respondió a tiempo."
  exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Creando usuario 'pepesan' con sudo"
echo "════════════════════════════════════════════════════════════════"
lxc exec "$NAME" -- bash -c '
  set -e
  # Asegurar que existe el comando sudo, con el gestor de paquetes de cada familia.
  if ! command -v sudo &>/dev/null; then
    if command -v apt-get &>/dev/null; then
      apt-get update -qq && apt-get install -y -qq sudo
    elif command -v dnf &>/dev/null; then
      dnf install -y -q sudo
    elif command -v zypper &>/dev/null; then
      zypper --non-interactive install sudo
    else
      echo "ERROR: no se encontró un gestor de paquetes soportado para instalar sudo." >&2
      exit 1
    fi
  fi
  # La imagen LXD de openSUSE Tumbleweed no trae /etc/sudoers en absoluto
  # (artefacto de esa imagen concreta, no de una instalación real de
  # openSUSE) -- sin esto, sudo rechaza cualquier contraseña porque no hay
  # ninguna regla de autorización que conceda nada a nadie. Se recrea con el
  # contenido de fábrica habitual (grupo wheel habilitado).
  if [ ! -f /etc/sudoers ]; then
    cat > /etc/sudoers <<'"'"'SUDOERS_EOF'"'"'
root ALL=(ALL:ALL) ALL
%wheel ALL=(ALL:ALL) ALL
%sudo ALL=(ALL:ALL) ALL
@includedir /etc/sudoers.d
SUDOERS_EOF
    chmod 0440 /etc/sudoers
  fi
  useradd -m -s /bin/bash pepesan
  echo "pepesan:pepesan" | chpasswd
  # "wheel" en RedHat/openSUSE, "sudo" en Debian/Ubuntu -- crear el grupo si
  # falta (la misma imagen de openSUSE tampoco trae "wheel" precreado) y
  # añadir a pepesan.
  getent group sudo &>/dev/null || groupadd sudo
  getent group wheel &>/dev/null || groupadd wheel
  usermod -aG sudo,wheel pepesan
  mkdir -p /home/pepesan/k8s-labs
  chown pepesan:pepesan /home/pepesan/k8s-labs
'

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Copiando scripts base"
echo "════════════════════════════════════════════════════════════════"
for f in 00_instalar_ansible.sh 01_bootstrap_host.sh lib_sudo.sh 00_bootstrap_host_lxd.yml check_requisitos.yml; do
  lxc file push "$BASE_DIR/$f" "$NAME/home/pepesan/k8s-labs/" >/dev/null
done
lxc exec "$NAME" -- bash -c 'chown -R pepesan:pepesan /home/pepesan/k8s-labs && chmod +x /home/pepesan/k8s-labs/*.sh'

IP="$(lxc list "$NAME" -f csv -c 4 | cut -d' ' -f1)"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Listo"
echo "════════════════════════════════════════════════════════════════"
echo "  Nombre:      $NAME"
echo "  Distro:      $DISTRO ($IMAGE)"
echo "  IP:          $IP"
echo "  Usuario:     pepesan  (contraseña: pepesan)"
echo "  Scripts en:  /home/pepesan/k8s-labs/"
echo ""
echo "  Entra con:"
echo "    lxc exec $NAME -- su - pepesan"
echo "    cd ~/k8s-labs && ./00_instalar_ansible.sh"
echo ""
echo "  Destrúyela cuando termines con:"
echo "    lxc delete -f $NAME"
echo "════════════════════════════════════════════════════════════════"
