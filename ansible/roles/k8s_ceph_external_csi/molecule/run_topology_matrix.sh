#!/usr/bin/env bash
# Sweeps this role against all 4 k8s_ha_cluster topologies (default=2m+1w,
# ha_1x2=1m+2w, ha_3x3=3m+3w, single_manager=1m+0w), keeping the external
# Ceph cluster side fixed (1 mon + 3 OSD, already proven on its own by
# ceph_external_cluster's scenario) — confirms the ceph-csi integration
# works the same regardless of the k8s cluster's size/HA shape.
#
# Unlike k8s_ha_cluster's own run_matrix.sh (24 combinations, converge-only
# to keep total time down), this sweep is only 4 scenarios, so it runs the
# FULL "molecule test" per topology (including native "idempotence") —
# affordable at this scale, and this cross-cluster integration logic is new
# enough to deserve the same rigor every other scenario in this repo got.
#
# Resumable: results already recorded in the results file are skipped on a
# re-run, so an interrupted sweep can just be re-invoked.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$SCRIPT_DIR/.."

# Lives at the ansible/roles/ level (not buried in this role's own
# molecule/ dir) so every role's matrix results are visible together in
# one place.
RESULTS_FILE="$ROLES_DIR/k8s_ceph_external_csi_topology_matrix_results.csv"
[ -f "$RESULTS_FILE" ] || echo "topology,result,duration_seconds" > "$RESULTS_FILE"

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

TOPOLOGIES=(single_manager default ha_1x2 ha_3x3)

already_done() {
  local topology="$1"
  grep -q "^${topology}," "$RESULTS_FILE"
}

for topology in "${TOPOLOGIES[@]}"; do
  if already_done "$topology"; then
    echo "SKIP (already recorded): $topology"
    continue
  fi

  log_file="$LOG_DIR/${topology}.log"
  echo "════════════════════════════════════════════════════════════════"
  echo "  $topology  (log: $log_file)"
  echo "════════════════════════════════════════════════════════════════"

  # Reset any stale cached "already prepared/created" molecule state first
  # (same reasoning as k8s_ha_cluster's run_matrix.sh: an interrupted prior
  # run's state would otherwise make the next "molecule test" silently skip
  # steps that never actually happened this time).
  timeout --signal=KILL 300 molecule destroy -s "$topology" > "$log_file" 2>&1 || true

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

  echo "${topology},${result},${duration}" >> "$RESULTS_FILE"
  echo ">>> RESULT: $topology => $result (${duration}s)"
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Topology matrix sweep complete — see $RESULTS_FILE"
echo "════════════════════════════════════════════════════════════════"
column -s, -t "$RESULTS_FILE"
