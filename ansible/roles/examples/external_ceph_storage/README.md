# external_ceph_storage

Two genuinely independent clusters — a standalone Ceph cluster and a Kubernetes cluster — joined only
by `ceph-csi`. Chains: `lxd_host_bootstrap` (optional, commented out) → `lxd_machine_provision` (once
per cluster) → `ceph_external_cluster` → `k8s_ha_cluster` (`csi: none`, since Ceph provides storage
instead) → `k8s_ceph_external_csi`.

## Usage

```bash
# From this directory, or set ANSIBLE_ROLES_PATH=../.. to run from elsewhere.
ansible-playbook -i inventory.ini playbook.yml
```

`inventory.ini` provisions 1 monitor + 3 OSDs for the Ceph side (a hard floor — `ceph_external_cluster`
waits for every declared OSD host to come up, and Ceph itself needs at least this many to be usefully
redundant) and a single-manager Kubernetes cluster (cheapest topology, since this example's whole point
is the cross-cluster wiring, not HA).

## Before running against your own host

- Adjust `ansible_host` IPs/sizes in `inventory.ini` to fit your LXD host's subnet and capacity.
- `lxd_extra_disk` on the 3 OSD hosts is required — Ceph needs a raw block device beyond the root disk
  for OSD backing storage.
- `k8s_vip_address`/`k8s_vip_interface` in `playbook.yml` must be correct for your network.
- Uncomment the `lxd_host_bootstrap` play if this is a genuinely fresh host.
