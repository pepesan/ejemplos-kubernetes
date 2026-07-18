#!/usr/bin/env bash
# Sweeps every distro this role claims to support (meta/main.yml) against
# the cheapest topology (single_manager: 1 VM, csi: none, headlamp: false),
# to validate the OS-level package/repo installs (containerd, kubeadm
# tooling) actually work on each one — not re-covering CNI/CSI/topology,
# which run_matrix.sh already sweeps separately, on Ubuntu 26.04 only.
#
# Runs the FULL "molecule test" (including "idempotence") per distro,
# unlike run_matrix.sh: this is new, unproven-per-distro code, same rigor
# lxd_host_bootstrap applied to its own RHEL-family work.
#
# Resumable: results already recorded in the results file are skipped on a
# re-run.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

RESULTS_FILE="$SCRIPT_DIR/distro_matrix_results.csv"
[ -f "$RESULTS_FILE" ] || echo "distro,image_alias,result,duration_seconds" > "$RESULTS_FILE"

# Per-distro logs, written directly (not through a pipe to "tail" or
# similar, which would buffer until EOF) so each one is tail-able live
# while the sweep is still running.
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

# alias:remote_image pairs, matching single_manager/prepare_images.yml.
DISTROS=(
  "ubuntu-24.04:k8s-ha-test-ubuntu-2404"
  "ubuntu-26.04:k8s-ha-test-ubuntu-2604"
  "debian-12:k8s-ha-test-debian-12"
  "debian-13:k8s-ha-test-debian-13"
  "rocky-9:k8s-ha-test-rocky-9"
  "fedora-43:k8s-ha-test-fedora-43"
  "fedora-44:k8s-ha-test-fedora-44"
)

already_done() {
  local distro="$1"
  grep -q "^${distro}," "$RESULTS_FILE"
}

echo "════════════════════════════════════════════════════════════════"
echo "  Importing VM-format test images (skips any already present)"
echo "════════════════════════════════════════════════════════════════"
ANSIBLE_ROLES_PATH="$SCRIPT_DIR/.." ansible-playbook -i "localhost," single_manager/prepare_images.yml

for entry in "${DISTROS[@]}"; do
  distro="${entry%%:*}"
  image_alias="${entry##*:}"

  if already_done "$distro"; then
    echo "SKIP (already recorded): $distro"
    continue
  fi

  log_file="$LOG_DIR/${distro}.log"
  echo "════════════════════════════════════════════════════════════════"
  echo "  $distro ($image_alias)  (log: $log_file)"
  echo "════════════════════════════════════════════════════════════════"

  export K8S_HA_CLUSTER_TEST_DISTRO_IMAGE="$image_alias"

  # "timeout --signal=KILL" doesn't reach ansible-playbook grandchildren
  # molecule spawns (confirmed live in run_matrix.sh's own hardening) — kill
  # any orphaned ones for this scenario after a timeout, same as there.
  start_ts=$(date +%s)
  timeout --signal=KILL 3600 molecule test -s single_manager > "$log_file" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    result="pass"
  elif [ "$rc" -eq 137 ]; then
    result="timeout"
    echo "!!! TIMED OUT after 3600s — killing orphaned children" >> "$log_file"
    pkill -9 -f "ansible-playbook.*molecule\.[A-Za-z0-9]*\.single_manager[/ ]" 2>/dev/null || true
  else
    result="fail"
  fi
  end_ts=$(date +%s)
  duration=$((end_ts - start_ts))

  echo "${distro},${image_alias},${result},${duration}" >> "$RESULTS_FILE"
  echo ">>> RESULT: $distro => $result (${duration}s)"
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Distro sweep complete — see $RESULTS_FILE"
echo "════════════════════════════════════════════════════════════════"
column -s, -t "$RESULTS_FILE"
