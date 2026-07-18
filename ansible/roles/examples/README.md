# Examples

Runnable playbooks showing how to combine the roles in `ansible/roles/` into complete, real setups —
not just the minimal per-role snippet each role's own README shows under "Example Playbook", but a full
inventory + playbook you can actually point at real LXD hosts and run end to end.

Each example assumes `lxd_host_bootstrap` has already prepared the LXD host (or runs it itself, see
below), and that `ansible-playbook` can resolve every role by name — run from this directory, or set
`ANSIBLE_ROLES_PATH` to `ansible/roles/` (one level up), same as every role's own Molecule scenario does.

- [`full_cluster_pxc/`](full_cluster_pxc/): bootstraps an LXD host, provisions a full HA Kubernetes
  cluster with Longhorn storage, installs the Percona Operator for MySQL (PXC/Galera), then
  demonstrates adding and removing a worker node — chains `lxd_host_bootstrap` →
  `lxd_machine_provision` → `k8s_ha_cluster` → `db_operator` → `k8s_node_scale_cycle`.
- [`external_ceph_storage/`](external_ceph_storage/): bootstraps a standalone Ceph cluster and a
  separate Kubernetes cluster, then wires them together via `ceph-csi` — chains
  `lxd_machine_provision` (twice, once per cluster) → `ceph_external_cluster` → `k8s_ha_cluster` →
  `k8s_ceph_external_csi`.

These are meant to be copied and adapted (real IPs, real capacity), not run unmodified against
production — the inventories use the same `10.207.154.0/24` subnet `lxd_host_bootstrap` sets up by
default, purely as a starting point.
