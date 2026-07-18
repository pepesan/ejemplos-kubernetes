# full_cluster_pxc

A complete, real HA Kubernetes cluster with Longhorn storage and the Percona Operator for MySQL
(PXC/Galera) installed, plus a demo of adding and removing a worker node. Chains:

`lxd_host_bootstrap` (optional, commented out — skip if the host is already prepared) →
`lxd_machine_provision` → `k8s_ha_cluster` (Flannel + Longhorn + Headlamp) → `db_operator` (`pxc`) →
`k8s_node_scale_cycle` (separate playbooks, run on demand).

## Usage

```bash
# From this directory, or set ANSIBLE_ROLES_PATH=../.. to run from elsewhere.
ansible-playbook -i inventory.ini playbook.yml

# Optional: demonstrate adding/removing a worker node afterward
ansible-playbook -i inventory.ini scale_add_node.yml
ansible-playbook -i inventory.ini scale_remove_node.yml
```

`inventory.ini` provisions 2 managers + 2 workers (4 VMs) for the base cluster, plus a `new_workers`
scratch host used only by the scale playbooks — `playbook.yml` never touches that group.

## Before running against your own host

- Adjust `ansible_host` IPs/`lxd_cpu`/`lxd_mem`/`lxd_disk` in `inventory.ini` to fit your LXD host's
  subnet and available capacity (defaults assume `lxd_host_bootstrap`'s own `10.207.154.0/24`).
- `k8s_vip_address` (`playbook.yml`) and `k8s_vip_interface` must be reachable/correct for your
  network — a wrong VIP silently breaks HA failover, not something a first run will surface.
- Uncomment the `lxd_host_bootstrap` play in `playbook.yml` if this is a genuinely fresh host.
