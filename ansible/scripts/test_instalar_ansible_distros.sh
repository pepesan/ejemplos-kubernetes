#!/usr/bin/env bash
# Smoke-tests ansible/base/00_instalar_ansible.sh (multi-distro Ansible
# installer via pipx) against the 2 latest stable releases of every distro it
# aims to support: Ubuntu, Debian, Rocky Linux, Fedora and openSUSE.
#
# Rocky only has one release tested live (9): no LXD image is published for
# Rocky 10 yet, same blocker already documented for lxd_host_bootstrap.
# openSUSE tests Leap 16.0 + Tumbleweed instead of two Leap releases, since no
# 15.x LXD image is published anymore either.
#
# For each distro: launches a plain throwaway LXD container, pushes the
# installer script into it, runs it as root with SKIP_CHECK_REQUISITOS=true
# (no real LXD/lxc inside the test container, so the final check_requisitos.yml
# step doesn't apply here), and checks that ansible-playbook ends up working.
# Always deletes every test container afterwards, run succeeds or not.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../base/00_instalar_ansible.sh"
CONTAINER_PREFIX="test-instalar-ansible"

declare -A DISTRO_IMAGES=(
  [ubuntu-2404]="ubuntu:24.04"
  [ubuntu-2604]="ubuntu:26.04"
  [debian-12]="images:debian/12"
  [debian-13]="images:debian/13"
  [rocky-9]="images:rockylinux/9"
  [fedora-43]="images:fedora/43"
  [fedora-44]="images:fedora/44"
  [opensuse-16]="images:opensuse/16.0"
  [opensuse-tumbleweed]="images:opensuse/tumbleweed"
)

FAILED=()

cleanup() {
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  Limpiando contenedores de prueba"
  echo "════════════════════════════════════════════════════════════════"
  for distro in "${!DISTRO_IMAGES[@]}"; do
    lxc delete --force "${CONTAINER_PREFIX}-${distro}" 2>/dev/null || true
  done
}
trap cleanup EXIT

for distro in "${!DISTRO_IMAGES[@]}"; do
  image="${DISTRO_IMAGES[$distro]}"
  name="${CONTAINER_PREFIX}-${distro}"

  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  $distro ($image)"
  echo "════════════════════════════════════════════════════════════════"

  lxc launch "$image" "$name" >/dev/null

  for _ in $(seq 1 30); do
    lxc exec "$name" -- true &>/dev/null && break
    sleep 2
  done

  lxc file push "$INSTALL_SCRIPT" "$name/root/00_instalar_ansible.sh" >/dev/null

  if lxc exec "$name" -- env SKIP_CHECK_REQUISITOS=true bash /root/00_instalar_ansible.sh \
    && lxc exec "$name" -- bash -c 'export PATH="$HOME/.local/bin:$PATH"; ansible-playbook --version && kubectl version --client && helm version'; then
    echo "OK: $distro"
  else
    echo "FALLO: $distro"
    FAILED+=("$distro")
  fi
done

echo ""
echo "════════════════════════════════════════════════════════════════"
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "  Distros con fallos: ${FAILED[*]}"
  echo "════════════════════════════════════════════════════════════════"
  exit 1
fi
echo "  Todas las distros instalaron Ansible correctamente"
echo "════════════════════════════════════════════════════════════════"
