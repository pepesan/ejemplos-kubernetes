# Ansible Roles

Standalone, reusable Ansible roles extracted from the logic duplicated across the `ansible/base/` labs. They are not (yet) wired into any lab — each is self-contained, with its own Molecule test scenario(s). Written entirely in English (code, comments, documentation and tests), unlike the Spanish-language labs in `ansible/base/`.

- [`lxd_host_bootstrap`](lxd_host_bootstrap/): prepares a host to run the `ansible/base/` labs — installs LXD, `kubectl` and `helm`, initializes LXD's network/storage/profile, and imports the base VM image every lab instance is cloned from.
- [`lxd_machine_provision`](lxd_machine_provision/): creates LXD instances (virtual machines or containers, selectable per group or per host) for a given inventory group, waits for them to become reachable, and injects the host's SSH public key.
- [`k8s_ha_cluster`](k8s_ha_cluster/): turns a set of already-provisioned instances into a working HA Kubernetes cluster (kubeadm + kube-vip), with a swappable CNI (Flannel/Cilium), an optional swappable CSI/storage backend (Longhorn/Rook Ceph) and an optional Headlamp dashboard.
- [`ceph_external_cluster`](ceph_external_cluster/): bootstraps a standalone Ceph cluster via `cephadm` (one monitor + a set of OSD nodes), independent of any Kubernetes cluster.
- [`k8s_ceph_external_csi`](k8s_ceph_external_csi/): wires an already-running Kubernetes cluster to consume an already-bootstrapped `ceph_external_cluster` via `ceph-csi`.
- [`db_operator`](db_operator/): installs a database operator (Percona's PXC/MySQL, PostgreSQL or MongoDB operator, or `mariadb-operator`) into an already-running Kubernetes cluster via Helm.

See each role's own `README.md` for its full variable reference, usage example and testing instructions.

## Backlog and status

See [`PLAN.md`](PLAN.md) for the full backlog of planned roles, validation status of the ones already implemented, and notes from reviewing similar published roles.
