#!/usr/bin/env bash
# Sweeps this role's default scenario once per operator (pxc, postgresql,
# mongodb, mariadb), each installed standalone rather than bundled with the
# other 3 (the normal, non-matrix "molecule test" run) — proves no operator
# implicitly depends on shared cluster state left behind by another.
#
# Only 4 runs, so this runs the FULL "molecule test" per operator
# (including native "idempotence") — affordable at this scale, same
# reasoning as k8s_ceph_external_csi's own run_topology_matrix.sh.
#
# Resumable: results already recorded in the results file are skipped on a
# re-run, so an interrupted sweep can just be re-invoked.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$SCRIPT_DIR/.."

# Lives at the ansible/roles/ level — see k8s_ha_cluster/molecule/run_matrix.sh
# for why (every role's matrix results visible together in one place).
RESULTS_FILE="$ROLES_DIR/db_operator_matrix_results.csv"
[ -f "$RESULTS_FILE" ] || echo "operator,result,duration_seconds" > "$RESULTS_FILE"

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

OPERATORS=(pxc postgresql mongodb mariadb)

already_done() {
  local operator="$1"
  grep -q "^${operator}," "$RESULTS_FILE"
}

for operator in "${OPERATORS[@]}"; do
  if already_done "$operator"; then
    echo "SKIP (already recorded): $operator"
    continue
  fi

  log_file="$LOG_DIR/${operator}.log"
  echo "════════════════════════════════════════════════════════════════"
  echo "  $operator  (log: $log_file)"
  echo "════════════════════════════════════════════════════════════════"

  # Reset any stale cached "already prepared/created" molecule state first
  # (same reasoning as k8s_ha_cluster's run_matrix.sh: an interrupted prior
  # run's state would otherwise make the next "molecule test" silently skip
  # steps that never actually happened this time).
  timeout --signal=KILL 300 molecule destroy > "$log_file" 2>&1 || true

  export DB_OPERATOR_TEST_NAMES="$operator"

  start_ts=$(date +%s)

  # "timeout --signal=KILL" doesn't reach ansible-playbook grandchildren
  # molecule spawns (confirmed live in k8s_ha_cluster's own hardening) —
  # kill any orphaned ones for this scenario after a timeout.
  timeout --signal=KILL 1800 molecule test >> "$log_file" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    result="pass"
  elif [ "$rc" -eq 137 ]; then
    result="timeout"
    echo "!!! TIMED OUT after 1800s — killing orphaned children" >> "$log_file"
    pkill -9 -f "ansible-playbook.*molecule\.[A-Za-z0-9]*\.default[/ ]" 2>/dev/null || true
  else
    result="fail"
  fi

  end_ts=$(date +%s)
  duration=$((end_ts - start_ts))

  echo "${operator},${result},${duration}" >> "$RESULTS_FILE"
  echo ">>> RESULT: $operator => $result (${duration}s)"
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Operator matrix sweep complete — see $RESULTS_FILE"
echo "════════════════════════════════════════════════════════════════"
column -s, -t "$RESULTS_FILE"
