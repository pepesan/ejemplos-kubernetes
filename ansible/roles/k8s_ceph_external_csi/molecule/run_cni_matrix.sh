#!/usr/bin/env bash
# Sweeps this role against both k8s_ha_cluster CNIs (flannel, cilium) across
# all 4 topology scenarios (default=2m+1w, ha_1x2=1m+2w, ha_3x3=3m+3w,
# single_manager=1m+0w) — 8 combinations. CSI itself isn't an axis here: it's
# fixed at "external Ceph" by design, the entire point of this role (see
# run_topology_matrix.sh, which already sweeps the topology axis alone with
# CNI fixed at flannel). This script adds the CNI axis on top, confirming
# the ceph-csi integration works regardless of which CNI the k8s cluster
# uses, not just its size/HA shape.
#
# 8 combinations, so this runs the FULL "molecule test" per combination
# (including native "idempotence") — same reasoning as run_topology_matrix.sh
# (affordable at this scale, this integration logic deserves the same rigor
# every other scenario in this repo got).
#
# Resumable: results already recorded in the results file are skipped on a
# re-run, so an interrupted sweep can just be re-invoked.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$SCRIPT_DIR/.."

# Lives at the ansible/roles/ level — see run_topology_matrix.sh for why.
RESULTS_FILE="$ROLES_DIR/k8s_ceph_external_csi_cni_matrix_results.csv"
[ -f "$RESULTS_FILE" ] || echo "cni,topology,result,duration_seconds" > "$RESULTS_FILE"

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

CNIS=(flannel cilium)
TOPOLOGIES=(single_manager default ha_1x2 ha_3x3)

already_done() {
  local cni="$1" topology="$2"
  grep -q "^${cni},${topology}," "$RESULTS_FILE"
}

for cni in "${CNIS[@]}"; do
  for topology in "${TOPOLOGIES[@]}"; do
    if already_done "$cni" "$topology"; then
      echo "SKIP (already recorded): $cni / $topology"
      continue
    fi

    log_file="$LOG_DIR/${cni}_${topology}.log"
    echo "════════════════════════════════════════════════════════════════"
    echo "  $cni / $topology  (log: $log_file)"
    echo "════════════════════════════════════════════════════════════════"

    # Reset any stale cached "already prepared/created" molecule state first
    # (same reasoning as k8s_ha_cluster's run_matrix.sh: an interrupted
    # prior run's state would otherwise make the next "molecule test"
    # silently skip steps that never actually happened this time).
    timeout --signal=KILL 300 molecule destroy -s "$topology" > "$log_file" 2>&1 || true

    export K8S_CEPH_EXTERNAL_CSI_TEST_CNI="$cni"

    start_ts=$(date +%s)

    # "timeout --signal=KILL" doesn't reach ansible-playbook grandchildren
    # molecule spawns (confirmed live in k8s_ha_cluster's own hardening) —
    # kill any orphaned ones for this scenario after a timeout.
    timeout --signal=KILL 3600 molecule test -s "$topology" >> "$log_file" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
      result="pass"
    elif [ "$rc" -eq 137 ]; then
      result="timeout"
      echo "!!! TIMED OUT after 3600s — killing orphaned children" >> "$log_file"
      pkill -9 -f "ansible-playbook.*molecule\.[A-Za-z0-9]*\.${topology}[/ ]" 2>/dev/null || true
    else
      result="fail"
    fi

    end_ts=$(date +%s)
    duration=$((end_ts - start_ts))

    echo "${cni},${topology},${result},${duration}" >> "$RESULTS_FILE"
    echo ">>> RESULT: $cni / $topology => $result (${duration}s)"
  done
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  CNI x topology matrix sweep complete — see $RESULTS_FILE"
echo "════════════════════════════════════════════════════════════════"
column -s, -t "$RESULTS_FILE"
