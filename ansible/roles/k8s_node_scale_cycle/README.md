# k8s_node_scale_cycle

Safely adds or removes a node from an already-running `k8s_ha_cluster`-built cluster. Faithfully
extracted from `ansible/base/03_k8s_ha_almacenamiento_persistente_longhorn` (add/integrate) and
`ansible/base/10_k8s_percona_mysql_pxc/17_eliminar_nodos.yml` (the correct Longhorn
instance-manager PodDisruptionBudget workaround — the only base lab that solves this properly
instead of a crude `pause: 15s`).

Operation selected by `k8s_node_scale_cycle_operation: add|remove` (task-file-indexed-by-name,
same convention `k8s_ha_cluster` uses for its `cni`/`csi` selection).

## `add`

1. Provisions the new node's VM via `lxd_machine_provision` (already replicates the full
   create/wait-for-agent/inject-ssh-key/wait-for-ssh sequence — no duplicated provisioning logic
   here).
2. Reuses `k8s_ha_cluster`'s own `os_prepare.yml`/`containerd.yml`/`k8s_tools.yml` task files via a
   relative import, pointed at the new node group — proven OS/containerd/kubeadm-tooling setup,
   not duplicated.
3. Mints a **fresh** `kubeadm token create --print-join-command` on the first manager and joins
   the new node with it. Deliberately does **not** reuse `k8s_ha_cluster`'s own
   `workers_join.yml`, which reads a join token cached in a local file at initial cluster
   creation — likely expired (kubeadm tokens are short-lived) by the time a real day-2 scale-up
   happens.
4. Waits for the new node to be `Ready`.
5. Optionally integrates it into Longhorn (`k8s_node_scale_cycle_longhorn_enabled`, default
   `true`): labeled as a storage node by default, or as a workload (compute-only) node if listed
   in the `k8s_node_scale_cycle_new_workload_nodes` opt-out list.

## `remove`

1. Per node: patches `nodes.longhorn.io/<node>` to `allowScheduling: false`, then waits
   (`until`/`retries`, not a fixed `pause`) for every real Longhorn replica to evacuate the node.
2. Deletes the node's `instance-manager` pod directly — this bypasses its own
   0-disruption-allowed PodDisruptionBudget, safe now that no real replica remains on it. This is
   the actual reason `kubectl drain` would otherwise hang forever: the `instance-manager` Pod
   isn't a real DaemonSet and has its own PDB.
3. `kubectl drain --delete-emptydir-data --ignore-daemonsets --force`.
4. `kubeadm reset -f` on the node itself.
5. Deletes the Longhorn node object and the Kubernetes `Node` object.
6. Destroys the LXD VM.

**Out of scope**: app-level scale-down (e.g. reducing a PXC cluster's size, checking `wsrep_*`
health before removing a node it's running on). That must happen separately, before invoking this
role with `operation: remove` — matches how the base lab itself sequences app-scale-down first,
then generic node teardown.

## Requirements

- An already-running cluster built by `k8s_ha_cluster`, with a fetched admin kubeconfig.
- Invoke against `hosts: <new_nodes_group>:<first_manager_group>:localhost` for `add` (or
  `<nodes_to_remove>:localhost` for `remove`) — each task file guards itself by group membership,
  same convention `k8s_ha_cluster` uses.

## Role Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `k8s_node_scale_cycle_operation` | `add` | `add` or `remove` |
| `k8s_node_scale_cycle_new_nodes_group` | `new_workers` | Inventory group holding the new node(s) to add |
| `k8s_node_scale_cycle_first_manager_group` | `first_manager` | Single-host group that mints fresh join tokens |
| `k8s_node_scale_cycle_kubeconfig_path` | `{{ inventory_dir }}/kubeconfig.yaml` | Admin kubeconfig of the cluster being scaled |
| `k8s_node_scale_cycle_longhorn_enabled` | `true` | Whether to run the Longhorn-specific add/remove steps |
| `k8s_node_scale_cycle_new_workload_nodes` | `[]` | Opt-out: new nodes here become workload (compute-only), not storage |
| `k8s_node_scale_cycle_nodes_to_remove` | `[]` | List of node hostnames to remove |

## Example Playbook

```yaml
# Add a node. gather_facts: false is required — the new node doesn't exist
# yet at play start (this role's own add.yml provisions it via
# lxd_machine_provision), and implicit fact gathering would try to connect
# to it before that happens and fail UNREACHABLE.
- hosts: new_workers:first_manager:localhost
  gather_facts: false
  roles:
    - role: k8s_node_scale_cycle
      vars:
        k8s_node_scale_cycle_operation: add

# Remove a node
- hosts: localhost
  roles:
    - role: k8s_node_scale_cycle
      vars:
        k8s_node_scale_cycle_operation: remove
        k8s_node_scale_cycle_nodes_to_remove: ["worker3"]
```

## Testing

One Molecule scenario: a real add-then-remove cycle against a live Longhorn-backed cluster (this
role's whole point is the Longhorn PDB interaction, so skipping Longhorn in the test would skip
the only risky logic).

```bash
cd ansible/roles/k8s_node_scale_cycle
molecule test
```

`prepare.yml` provisions a base 2-worker set via `lxd_machine_provision`, then `k8s_ha_cluster`
(`csi: longhorn`, Flannel, no Headlamp) brings up the starting cluster. `converge.yml` runs this
role with `operation: add` against a `new_workers` group (1 host), then immediately with
`operation: remove` targeting that same new node — proving both directions work together in one
cycle. `verify.yml` asserts the removed node's Kubernetes `Node` object, Longhorn node object and
LXD VM are all gone, and that the *original* 2 workers are still `Ready` (proving the removal
didn't collaterally disrupt the rest of the cluster). Includes Molecule's native `idempotence`
step, scoped to a re-run of the `add` operation only (`remove` is inherently one-shot against a
node that's already gone).
