#!/usr/bin/env bash
# Builds a Rocky Linux 10 LXD virtual-machine image locally and imports it as
# rockylinux/10/vm, since no published image exists yet on the public remote
# (see ansible/roles/lxd_machine_provision/README.md, "Building images not
# yet published") — confirmed empty again while writing this script:
# `lxc image list images:rockylinux/10` returns nothing, only Rocky 8/9 are
# published.
#
# Three real problems had to be worked around, all confirmed live (booting
# an actual VM and reading its console/journal) rather than assumed:
#
#   1. The distrobuilder snap (both latest/stable and latest/edge channels)
#      is stale — the edge channel is pinned to a build from 2025-06-18,
#      which predates the upstream commit that added Rocky 10 support
#      (2025-08-03, "rockylinux: Add RockyLinux 10 support"). That commit is
#      what actually fixes the GPG bootstrap failure: for release 10 it adds
#      --nogpgcheck to the internal `dnf --installroot` bootstrap step
#      ("since rpmkeys isn't available" in the install ISO). There is no way
#      to get this fix from the snap store today, so this script builds
#      distrobuilder from source instead of using the snap.
#
#   2. distrobuilder's upstream rockylinux.yaml (lxc/lxc-ci) only wires up
#      its "incus-agent" generator for the virtio-serial port name Incus
#      uses ("org.linuxcontainers.incus"). This host runs Canonical LXD, not
#      Incus, and LXD names that same port "org.linuxcontainers.lxd" —
#      confirmed by reading the actual `-readconfig` qemu.conf LXD generates
#      for a running VM. Without a matching udev rule for that port name,
#      the udev rule that starts incus-agent.service never fires, and the
#      VM boots with a working network but `lxc exec`/`lxc list` IPv4
#      forever report "LXD VM agent is not currently running". This script
#      appends a second udev rule aliasing the LXD port name to the same
#      incus-agent.service, rather than patching distrobuilder.
#
#   3. Even with the udev rule firing, the service still failed to start:
#      confirmed by temporarily overriding the agent-setup script to trace
#      to the VM's serial console. The 9p mount fails (this Rocky 10 build
#      has no 9pnet_virtio kernel module — 9p support isn't in the minimal
#      variant), but the virtiofs fallback mount succeeds and copies the
#      config-drive contents fine. The failure is that LXD's own config
#      drive ships the agent binary as "lxd-agent", not "incus-agent" (that
#      naming comes from Incus's own image definition/unit), so
#      incus-agent.service's ExecStart=/run/incus_agent/incus-agent finds
#      nothing. This script's setup-script override symlinks incus-agent to
#      lxd-agent when only the latter is present, so it works booted under
#      either LXD or Incus.
#
# All three findings are specific to whatever distrobuilder/LXD versions are
# current when this script is run — re-verify them (don't just re-run
# blindly) if either project has moved on since.
set -euo pipefail

ARCH="${1:-x86_64}"
RELEASE="10"
IMAGE_ALIAS="rockylinux/${RELEASE}/vm"
WORK_DIR="$(mktemp -d /tmp/rocky10-build.XXXXXX)"
DISTROBUILDER_SRC="${WORK_DIR}/distrobuilder"
YAML_FILE="${WORK_DIR}/rockylinux.yaml"
OUTPUT_DIR="${WORK_DIR}/output"

cleanup() {
  echo ""
  echo "Build workspace left at: ${WORK_DIR}"
}
trap cleanup EXIT

echo "════════════════════════════════════════════════════════════════"
echo "  [1/5] Installing build dependencies (apt, needs sudo)"
echo "════════════════════════════════════════════════════════════════"
sudo apt-get update
sudo apt-get install -y dnf btrfs-progs golang-go make git pkg-config libacl1-dev

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  [2/5] Building distrobuilder from source"
echo "════════════════════════════════════════════════════════════════"
git clone --depth 1 https://github.com/lxc/distrobuilder.git "${DISTROBUILDER_SRC}"
(
  cd "${DISTROBUILDER_SRC}"
  export GOFLAGS=-tags=containers_image_storage_stub,containers_image_docker_daemon_stub,containers_image_openpgp
  go build -o ./distrobuilder-bin ./distrobuilder
)
"${DISTROBUILDER_SRC}/distrobuilder-bin" --version

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  [3/5] Fetching and patching the Rocky Linux image definition"
echo "════════════════════════════════════════════════════════════════"
curl -sL -o "${YAML_FILE}" \
  https://raw.githubusercontent.com/lxc/lxc-ci/main/images/rockylinux.yaml

# See findings 2 and 3 in the header comment above.
python3 - "${YAML_FILE}" <<'PYEOF'
import sys

path = sys.argv[1]
marker = "- generator: incus-agent\n  types:\n  - vm\n"
extra = '''
- path: /lib/udev/rules.d/99-lxd-agent.rules
  generator: dump
  content: |-
    SYMLINK=="virtio-ports/org.linuxcontainers.lxd", TAG+="systemd", ENV{SYSTEMD_WANTS}+="incus-agent.service"
  types:
  - vm

- path: /lib/systemd/incus-agent-setup
  generator: dump
  mode: "0755"
  content: |-
    #!/bin/sh
    set -eu
    PREFIX="/run/incus_agent"
    CDROM="/dev/disk/by-id/scsi-0QEMU_QEMU_CD-ROM_incus_agent"

    mount_virtiofs() {
        mount -t virtiofs config "${PREFIX}.mnt" >/dev/null 2>&1
    }

    mount_9p() {
        modprobe 9pnet_virtio >/dev/null 2>&1 || true
        mount -t 9p config "${PREFIX}.mnt" -o access=0,trans=virtio,size=1048576 >/dev/null 2>&1
    }

    mount_cdrom() {
        mount "${CDROM}" "${PREFIX}.mnt" >/dev/null 2>&1
    }

    fail() {
        if [ -x "${PREFIX}/incus-agent" ]; then
            echo "${1}, reusing existing agent"
            exit 0
        fi
        umount -l "${PREFIX}" >/dev/null 2>&1 || true
        eject "${CDROM}" >/dev/null 2>&1 || true
        rmdir "${PREFIX}" >/dev/null 2>&1 || true
        echo "${1}, failing"
        exit 1
    }

    mkdir -p "${PREFIX}.mnt"
    mount_9p || mount_virtiofs || mount_cdrom || fail "Couldn't mount 9p or cdrom"

    umount -l "${PREFIX}" >/dev/null 2>&1 || true
    mkdir -p "${PREFIX}"
    mount -t tmpfs tmpfs "${PREFIX}" -o mode=0700,size=50M

    cp -Ra "${PREFIX}.mnt/"* "${PREFIX}"

    # LXD's own config drive ships the agent binary as "lxd-agent" rather
    # than "incus-agent" (this generator/unit come from Incus's own image
    # definition). Alias it so incus-agent.service's ExecStart finds it
    # regardless of which of the two actually provided the config drive.
    if [ ! -e "${PREFIX}/incus-agent" ] && [ -e "${PREFIX}/lxd-agent" ]; then
        ln -s lxd-agent "${PREFIX}/incus-agent"
    fi

    umount "${PREFIX}.mnt"
    rmdir "${PREFIX}.mnt"

    eject "${CDROM}" >/dev/null 2>&1 || true

    chown -R root:root "${PREFIX}"

    restorecon -R "${PREFIX}" >/dev/null 2>&1 || true

    exit 0
  types:
  - vm
'''

with open(path) as f:
    content = f.read()

if marker not in content:
    sys.exit("marker not found in rockylinux.yaml — upstream definition changed, update this script")

if "99-lxd-agent.rules" not in content:
    content = content.replace(marker, marker + extra, 1)

with open(path, "w") as f:
    f.write(content)
PYEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  [4/5] Building the VM image (needs sudo: mounts/chroots the rootfs)"
echo "════════════════════════════════════════════════════════════════"
mkdir -p "${OUTPUT_DIR}"
sudo "${DISTROBUILDER_SRC}/distrobuilder-bin" build-incus "${YAML_FILE}" "${OUTPUT_DIR}" \
  -o "image.release=${RELEASE}" \
  -o "image.architecture=${ARCH}" \
  --vm --type=unified

IMAGE_TARBALL="$(find "${OUTPUT_DIR}" -maxdepth 1 -name '*.tar.xz' -print -quit)"
if [ -z "${IMAGE_TARBALL}" ]; then
  echo "Build finished but no .tar.xz found in ${OUTPUT_DIR}" >&2
  exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  [5/5] Importing into LXD as ${IMAGE_ALIAS}"
echo "════════════════════════════════════════════════════════════════"
if lxc image info "${IMAGE_ALIAS}" >/dev/null 2>&1; then
  lxc image delete "${IMAGE_ALIAS}"
fi
lxc image import "${IMAGE_TARBALL}" --alias "${IMAGE_ALIAS}"

echo ""
echo "Done. Verify with: lxc launch ${IMAGE_ALIAS} rocky10-test --vm && lxc exec rocky10-test -- cat /etc/os-release"
