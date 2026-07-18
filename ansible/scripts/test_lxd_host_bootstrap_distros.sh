#!/usr/bin/env bash
# Smoke-tests the lxd_host_bootstrap role across every distro it claims to
# support (see ansible/roles/lxd_host_bootstrap/meta/main.yml): spins up one
# throwaway LXD container per distro, runs the role's OS-package-level
# tasks against each over the community.general.lxd connection plugin
# (lxc exec, no SSH), and always tears the containers down afterwards.
# Two categories of task are skipped, both because they don't apply to a
# remote-target test the way this role is actually used in practice
# (connection: local, on the very machine you're bootstrapping):
#   - "requires_virtualization" (lxd_init/base_image): installing a nested
#     LXD daemon inside a test container isn't necessary to prove the
#     apt/snap/kernel-module logic works on that distro.
#   - "requires_ansible_control_node" (the Galaxy collections task):
#     assumes ansible-galaxy is already on the target, trivially true when
#     the target IS the control node (connection: local) but not for a
#     genuinely separate/fresh remote target like these test containers.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export ANSIBLE_ROLES_PATH="../roles"

cleanup() {
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  Cleaning up test containers"
  echo "════════════════════════════════════════════════════════════════"
  ansible-playbook -i inventory_distro_test.ini 03_destroy.yml
}
trap cleanup EXIT

echo "════════════════════════════════════════════════════════════════"
echo "  [1/3] Importing container-format test images"
echo "════════════════════════════════════════════════════════════════"
ansible-playbook -i inventory_distro_test.ini 00_prepare_images.yml

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  [2/3] Provisioning one throwaway container per distro"
echo "════════════════════════════════════════════════════════════════"
ansible-playbook -i inventory_distro_test.ini 01_provision.yml

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  [3/3] Running lxd_host_bootstrap against each distro"
echo "════════════════════════════════════════════════════════════════"
ansible-playbook -i inventory_distro_test.ini 02_bootstrap.yml \
  --skip-tags requires_virtualization,requires_ansible_control_node "$@"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  All distros passed lxd_host_bootstrap (OS-package-level tasks)"
echo "════════════════════════════════════════════════════════════════"
