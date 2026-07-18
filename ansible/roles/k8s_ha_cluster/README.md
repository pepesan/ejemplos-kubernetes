# k8s_ha_cluster

Turns a set of already-provisioned, already-bootstrapped LXD instances into a working HA Kubernetes
cluster. Faithfully extracted from `ansible/base/02_k8s_base_ha_3_managers_3_workers` (plus the CSI
backends from labs 03/04, and the Cilium CNI from lab 08), generalized into a single reusable role:

1. Prepares the OS on every node (swap off, kernel modules, sysctl).
2. Installs and configures containerd.
3. Installs kubelet/kubeadm/kubectl (held at their installed version).
4. Initializes the first control-plane node with kubeadm (`--upload-certs`, HA endpoint pointing at a
   kube-vip VIP) and installs the selected CNI.
5. Joins the remaining control-plane nodes (`kubeadm join --control-plane --certificate-key ...`, the
   default "stacked etcd" topology — every control-plane node runs its own etcd member, together forming
   a clustered etcd across the managers; no separate external-etcd setup) and the workers.
6. Optionally installs the selected CSI/storage backend.
7. Optionally deploys the Headlamp dashboard.

Requires `lxd_host_bootstrap` and `lxd_machine_provision` to have already run (or an equivalent
already-provisioned inventory: an LXD host with the target image imported, and a set of running
instances reachable over SSH as root).

## Requirements

- Ubuntu 24.04/26.04, Debian 12 (bookworm)/13 (trixie), Rocky Linux 9 (10 once an LXD image is
  published) or Fedora 43/44 instances — same platform set as `lxd_host_bootstrap`.
- A single invocation covering every node role: this role is meant to run against
  `hosts: k8s_nodes:localhost` (or equivalent) in one play — see "Example Playbook" below. Unlike
  `lxd_host_bootstrap`/`lxd_machine_provision` (each naturally scoped to one host group), this role spans
  managers, workers and cluster-level actions delegated to `localhost`, and each task file guards itself
  by inventory group membership rather than relying on separate plays per group.

### A note on Rocky Linux / Fedora (RHEL family)

`os_prepare.yml` is already OS-agnostic. `containerd.yml` and `k8s_tools.yml` dispatch to a
`_debian.yml`/`_redhat.yml` task file by `ansible_facts.os_family`, since the actual package/repo steps
differ:

- **containerd**: Docker publishes separate per-distro repos for RHEL-family — Fedora gets its own
  (`download.docker.com/linux/fedora`), Rocky/RHEL/CentOS share the CentOS one
  (`download.docker.com/linux/centos`), added via `ansible.builtin.yum_repository` rather than shelling
  out to `dnf config-manager`.
- **kubeadm/kubelet/kubectl**: `pkgs.k8s.io` publishes an RPM repo alongside its Debian one
  (`.../rpm/`), installed with `disable_excludes: kubernetes` (required per upstream Kubernetes docs, or
  the repo's own `exclude` list blocks the install it's meant to protect). Version-pinning equivalent to
  Debian's `dpkg_selections: hold` is `dnf versionlock` (needs the `python3-dnf-plugin-versionlock`
  package first, not present by default).

## Component selection

Two variables select swappable implementations by name, loading a different task file
(`tasks/cni/<name>.yml`, `tasks/csi/<name>.yml`) rather than toggling booleans — see `roles/PLAN.md` for
why this pattern was chosen over per-component on/off flags.

| Variable | Values | Default |
| --- | --- | --- |
| `k8s_ha_cluster_cni` | `flannel`, `cilium` | `flannel` |
| `k8s_ha_cluster_csi` | `none`, `longhorn`, `rook_ceph` | `none` |
| `k8s_ha_cluster_headlamp_enabled` | `true`, `false` | `true` |

`flannel`/`none`/`headlamp on` reproduces `base/02` exactly — the plainest HA cluster lab, chosen as the
default because it's the closest to a zero-surprise starting point.

### CNI: Flannel vs Cilium

Both are ported from labs that already run them for real. Cilium replaces kube-proxy entirely
(`kubeProxyReplacement: true`, the `kube-proxy` DaemonSet/ConfigMap removed, `k8sServiceHost`/
`k8sServicePort` pointed at the kube-vip VIP so the apiserver stays reachable) — the same setup
live-validated in `base/08_k8s_gateway_api` and reused by labs 10-14, pinned at the same
`k8s_ha_cluster_cilium_version` (`1.19.5`). The Gateway API CRDs and L2Announcement/LB-IPAM bits that
lab layers on top of Cilium are Gateway-API/LoadBalancer-specific extras, out of scope here.

### CSI: none, Longhorn, or Rook Ceph

Both backends are ported from labs that already run them for real (`base/03`, `base/04`). The
Ceph-externo backend (depends on an already-existing external Ceph cluster) is deferred — see
`roles/PLAN.md`.

Longhorn's dedicated workload/storage node pools are optional here:
`k8s_ha_cluster_longhorn_workload_group` and `..._storage_group` both default to
`k8s_ha_cluster_workers_group` (every worker does both compute and storage) unless the caller defines
separate pool groups in their inventory — generalizing `base/03`'s hard requirement for two distinct
groups into an opt-in. The `storage-node=true:NoSchedule` taint is only applied when the two pools are
genuinely distinct — found live: with a single, undivided workers group, tainting that one worker as
"storage-node" left nowhere for Longhorn's own `longhorn-ui`/`longhorn-driver-deployer` Deployments to
schedule (they don't tolerate that taint, only `longhorn-manager`'s DaemonSet does), so they'd sit
Pending forever.

**Note on `rook_ceph` defaults**: `base/04`'s own `group_vars/all.yml` references
`rook_ceph_chart_version`/`ceph_image` in its task file but never actually defines them — a pre-existing
bug in that base lab. This role's own defaults (`k8s_ha_cluster_rook_ceph_chart_version: "v1.20.2"`,
`k8s_ha_cluster_ceph_image: "quay.io/ceph/ceph:v20.2.2"`) were resolved independently via
`helm search repo`/`helm show values`, not copied from there.

**`rook_ceph` requires at least 3 workers**: Ceph's `mon.count: 3` needs 3 nodes without the
control-plane taint to reach quorum — mon pods can't schedule on tainted managers, so any topology
short of 3 workers never reaches quorum and the CephCluster never becomes healthy. `preflight_checks.yml`
(the very first thing the role does, before touching any node) refuses this combination immediately
with a clear error instead of letting the cluster half-converge and hang for minutes on something that
was never going to work.

## Role Variables

See `defaults/main.yml` for the full list. The most relevant, beyond component selection:

| Variable | Default | Purpose |
| --- | --- | --- |
| `k8s_ha_cluster_nodes_group` | `k8s_nodes` | All cluster nodes (managers + workers); OS prep/containerd/k8s tools run here |
| `k8s_ha_cluster_first_manager_group` | `first_manager` | Single-host group: the node that runs `kubeadm init` |
| `k8s_ha_cluster_additional_managers_group` | `additional_managers` | Remaining control-plane nodes |
| `k8s_ha_cluster_workers_group` | `workers` | Worker nodes |
| `k8s_vip_address` / `k8s_vip_interface` | *(required, no default)* | kube-vip HA endpoint — network-specific |
| `k8s_ha_cluster_kubeconfig_path` | `{{ inventory_dir }}/kubeconfig.yaml` | Where the fetched admin kubeconfig is saved, and read from by every cluster-facing task |

## Example Playbook

```yaml
- hosts: k8s_nodes:localhost
  roles:
    - role: k8s_ha_cluster
      vars:
        k8s_vip_address: "10.207.154.49"
        k8s_vip_interface: enp5s0
        k8s_ha_cluster_cni: cilium
        k8s_ha_cluster_csi: longhorn
```

Pointing this role at an existing base lab's inventory (e.g. `base/02`'s `inventory.ini`) needs zero
inventory changes — the default group names match exactly.

## Testing

Four Molecule scenarios, each a different topology, all against the real host (driver `default`,
`community.general.lxd_container` — this role needs genuine kubeadm/containerd, not an isolated
Docker/Podman container):

| Scenario | Topology | Exercises |
| --- | --- | --- |
| `default` | 2 managers + 1 worker | The multi-manager join path with a minimal node count |
| `ha_3x3` | 3 managers + 3 workers | The full topology, matching `base/02`+`base/03` exactly |
| `single_manager` | 1 manager, no workers | `control_plane_init.yml` on its own, empty group guards |
| `ha_1x2` | 1 manager + 2 workers | No `additional_managers`, 2 real worker joins |

```bash
cd ansible/roles/k8s_ha_cluster
molecule test              # default scenario
molecule test -s ha_3x3    # any other scenario
```

Each scenario's `converge.yml` reads `k8s_ha_cluster_cni`/`k8s_ha_cluster_csi` from the
`K8S_HA_CLUSTER_TEST_CNI`/`K8S_HA_CLUSTER_TEST_CSI` environment variables (falling back to that
scenario's normal default when unset), so the same 4 scenarios double as the topology axis of a full
CNI×CSI sweep:

```bash
./molecule/run_matrix.sh
```

Runs every combination of `{flannel,cilium} × {none,longhorn,rook_ceph}` across all 4 topologies (24
runs), skipping `idempotence` (a property of the role's tasks, not of the CNI/CSI choice — already
covered once per scenario's own normal `molecule test` run). Resumable: results already recorded in
`molecule/matrix_results.csv` are skipped on a re-run. Not every combination is viable — Rook Ceph
requires at least 3 workers (see above) and fails fast as `unsupported` on the 6 combinations that don't
have it, rather than being treated as a bug.

`molecule/run_distro_matrix.sh` sweeps the OS-family dimension instead (Ubuntu 24.04/26.04, Debian
12/13, Rocky 9, Fedora 43/44), reusing the cheapest scenario (`single_manager`) rather than multiplying
into the CNI×CSI matrix — see `roles/PLAN.md` for results.
