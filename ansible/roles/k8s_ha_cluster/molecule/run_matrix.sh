#!/usr/bin/env bash
# Sweeps every CNI x CSI combination across all 4 topology scenarios, to map
# out which combinations of k8s_ha_cluster are actually viable (not every
# combination necessarily makes sense — e.g. Rook Ceph hardcodes mon.count:
# 3, so it's expected to fail on the single-manager topology, which only
# has 1 node; that's exactly the kind of limit this sweep exists to find).
#
# Runs "molecule converge" + "molecule verify" + "molecule destroy"
# per combination rather than full "molecule test", deliberately skipping
# the "idempotence" step here: idempotency is a property of the role's
# tasks, already exercised once per scenario in each scenario's own normal
# "molecule test" run, not something that varies by CNI/CSI choice — running
# it 24 times over would roughly double this sweep's total wall-clock time
# for no new information.
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
RESULTS_FILE="$ROLES_DIR/k8s_ha_cluster_matrix_results.csv"
[ -f "$RESULTS_FILE" ] || echo "topology,cni,csi,result,duration_seconds" > "$RESULTS_FILE"

# Per-combination logs, written directly (not through a pipe to "tail" or
# similar, which would buffer until EOF) so each one is tail-able live
# while the sweep is still running.
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

TOPOLOGIES=(default ha_1x2 ha_3x3 single_manager)
CNIS=(flannel cilium)
CSIS=(none longhorn rook_ceph)

already_done() {
  local topology="$1" cni="$2" csi="$3"
  grep -q "^${topology},${cni},${csi}," "$RESULTS_FILE"
}

for topology in "${TOPOLOGIES[@]}"; do
  for cni in "${CNIS[@]}"; do
    for csi in "${CSIS[@]}"; do
      if already_done "$topology" "$cni" "$csi"; then
        echo "SKIP (already recorded): $topology / $cni / $csi"
        continue
      fi

      log_file="$LOG_DIR/${topology}_${cni}_${csi}.log"
      echo "════════════════════════════════════════════════════════════════"
      echo "  $topology / cni=$cni / csi=$csi  (log: $log_file)"
      echo "════════════════════════════════════════════════════════════════"

      export K8S_HA_CLUSTER_TEST_CNI="$cni"
      export K8S_HA_CLUSTER_TEST_CSI="$csi"

      start_ts=$(date +%s)
      result="pass"

      # Bounds every step so a single hung environment (a stuck SSH
      # connection, a stuck LXD operation like the "busy running a create
      # operation" race hit earlier this session) can't stall the whole
      # sweep indefinitely. Generous but bounded: Rook Ceph combinations
      # legitimately take the longest (mon/OSD bring-up with its own
      # internal retries), so converge gets the largest budget.
      #
      # "timeout --signal=KILL" only SIGKILLs the direct child (the
      # molecule python process) — it does NOT reach the ansible-playbook
      # grandchild molecule spawns, which gets orphaned and keeps running
      # (confirmed live earlier this session: a manual "pkill -9 -f
      # molecule" left ansible-playbook processes alive). Every step is
      # followed by an explicit sweep for orphaned ansible-playbook
      # processes tied to this scenario's ephemeral inventory path.
      kill_orphans() {
        pkill -9 -f "ansible-playbook.*molecule\.[A-Za-z0-9]*\.${topology}[/ ]" 2>/dev/null || true
      }

      run_step() {
        local step_name="$1" budget="$2"; shift 2
        echo "=== ${step_name}: $(date -Iseconds) (timeout ${budget}s) ==="
        timeout --signal=KILL "$budget" "$@"
        local rc=$?
        if [ "$rc" -eq 137 ]; then
          echo "!!! ${step_name} TIMED OUT after ${budget}s — killing orphaned children"
          kill_orphans
        fi
        return "$rc"
      }

      {
        # Molecule caches "already prepared"/"already created" state across
        # separate invocations (~/.cache/molecule/.../state.yml) — if a
        # previous run of this scenario was interrupted (crash, manual VM
        # cleanup outside molecule), that stale state makes the next
        # "molecule prepare" silently skip re-creating the instances.
        # Destroying first guarantees a clean slate every iteration,
        # regardless of what happened last time.
        run_step "destroy (reset stale state)" 300 molecule destroy -s "$topology" || true

        # "molecule converge" does NOT run "prepare" first on its own
        # (unlike full "molecule test") — these scenarios create their VMs
        # in prepare.yml (via lxd_machine_provision), so skipping this step
        # would converge against instances that don't exist yet.
        run_step "prepare" 600 molecule prepare -s "$topology"
        rc=$?
        [ "$rc" -eq 137 ] && result="timeout_prepare" || { [ "$rc" -ne 0 ] && result="fail_prepare"; }

        if [ "$result" = "pass" ]; then
          run_step "converge" 2400 molecule converge -s "$topology"
          rc=$?
          if [ "$rc" -eq 137 ]; then
            result="timeout_converge"
          elif [ "$rc" -ne 0 ]; then
            # The role's own preflight_checks.yml fails fast (in seconds, not
            # minutes) on combinations it knows can't work — e.g. rook_ceph
            # needs >=3 workers. Distinguish that from a genuine bug.
            if grep -q "k8s_ha_cluster_csi=rook_ceph is not supported on this topology" "$log_file"; then
              result="unsupported"
            else
              result="fail_converge"
            fi
          fi
        fi
        if [ "$result" = "pass" ]; then
          run_step "verify" 300 molecule verify -s "$topology"
          rc=$?
          [ "$rc" -eq 137 ] && result="timeout_verify" || { [ "$rc" -ne 0 ] && result="fail_verify"; }
        fi

        run_step "destroy" 300 molecule destroy -s "$topology" || true
      } > "$log_file" 2>&1

      end_ts=$(date +%s)
      duration=$((end_ts - start_ts))

      echo "${topology},${cni},${csi},${result},${duration}" >> "$RESULTS_FILE"
      echo ">>> RESULT: $topology / $cni / $csi => $result (${duration}s)"
    done
  done
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Matrix sweep complete — see $RESULTS_FILE"
echo "════════════════════════════════════════════════════════════════"
column -s, -t "$RESULTS_FILE"
