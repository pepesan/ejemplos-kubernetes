# k8s_ceph_external_csi

Wires an already-running Kubernetes cluster to consume an already-bootstrapped **external** Ceph
cluster (see [`ceph_external_cluster`](../ceph_external_cluster/)) via `ceph-csi` — two genuinely
independent clusters, joined only by this role. Faithfully extracted from
`ansible/base/05_k8s_ha_almacenamiento_persistente_externo_ceph`:

1. On the Ceph side: creates the RBD pool used for Kubernetes volumes, fetches the cluster's `fsid` and
   `client.admin` key.
2. On the Kubernetes side: creates the `ceph-csi` namespace and connection secret, installs the
   `ceph-csi-operator`/`ceph-csi-drivers` Helm charts wired to the external cluster via the
   `CephConnection`/`ClientProfile` CRDs, and creates a StorageClass backed by it.

This is deliberately a separate role from `k8s_ha_cluster` rather than a 4th `k8s_ha_cluster_csi`
value — this backend needs an entirely separate cluster with its own inventory groups and lifecycle,
unlike Longhorn/Rook Ceph which self-provision storage inside the k8s cluster itself (see
`roles/PLAN.md`, "the odd one out among the three").

## Requirements

- An already-bootstrapped external Ceph cluster (`ceph_external_cluster`).
- An already-running Kubernetes cluster with a fetched admin kubeconfig (e.g. `k8s_ha_cluster` with
  `csi: none`, since this role provides the storage instead).
- Both clusters' inventory groups present in the same play: run against
  `hosts: ceph_monitors:localhost` (or equivalent) — same "task files guard themselves by group
  membership" convention `k8s_ha_cluster` uses, since this role spans the Ceph monitor and the local
  control node (where `kubectl`/`helm` talk to the k8s cluster).

## Role Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `k8s_ceph_external_csi_ceph_monitors_group` | `ceph_monitors` | Where to fetch Ceph cluster credentials from |
| `k8s_ceph_external_csi_kubeconfig_path` | `{{ inventory_dir }}/kubeconfig.yaml` | Admin kubeconfig of the k8s cluster to configure |
| `k8s_ceph_external_csi_rbd_pool` | `rbd-k8s` | RBD pool created for Kubernetes volumes |
| `k8s_ceph_external_csi_chart_version` | `1.0.4` | `ceph-csi-operator`/`ceph-csi-drivers` chart version (same pin `k8s_ha_cluster`'s Rook Ceph backend already uses) |
| `k8s_ceph_external_csi_storage_class_name` | `ceph-block-external` | StorageClass name created for RBD volumes |

## Example Playbook

```yaml
- hosts: ceph_monitors:localhost
  roles:
    - k8s_ceph_external_csi
```

## Testing

Four Molecule scenarios, one per `k8s_ha_cluster` topology — the external Ceph cluster side stays fixed
(1 monitor + 3 OSDs, already proven on its own by `ceph_external_cluster`'s scenario) in every one:

| Scenario | k8s topology | Total VMs |
| --- | --- | --- |
| `single_manager` | 1 manager, 0 workers | 5 |
| `default` | 2 managers + 1 worker | 7 |
| `ha_1x2` | 1 manager + 2 workers | 7 |
| `ha_3x3` | 3 managers + 3 workers | 8 |

```bash
cd ansible/roles/k8s_ceph_external_csi
molecule test -s single_manager    # any scenario
```

Each scenario provisions its Ceph cluster (via `ceph_external_cluster`) and its k8s cluster (via
`k8s_ha_cluster`, `csi: none`, Flannel, no Headlamp — the cheapest possible base, since storage comes
from this role instead), then runs this role to tie them together. `verify.yml` goes beyond checking the
StorageClass exists: it creates a real PVC, waits for it to bind, and runs a pod that writes and reads
back a file through the RBD volume — proving the cross-cluster wiring actually works, not just that the
objects were created. Includes Molecule's native `idempotence` step.

```bash
./molecule/run_topology_matrix.sh
```

Runs the full `molecule test` for all 4 scenarios in sequence — confirms the CSI integration works the
same regardless of the k8s cluster's size/HA shape, not just on the one scenario tested directly.
Resumable: results already recorded in `../k8s_ceph_external_csi_topology_matrix_results.csv` (at the
`ansible/roles/` level, alongside every other role's own matrix results) are skipped on a re-run.
Per-scenario logs land in `molecule/logs/` (gitignored, unlike the results CSV).
