# lxd_machine_provision

Creates LXD instances — virtual machines or containers, indistinctly — for
every host in a given inventory group, then makes them reachable over SSH
as root:

1. Creates each instance (`community.general.lxd_container`) from the
   configured image alias, sized per host via `hostvars`.
2. Waits for the LXD agent to respond inside each instance.
3. Injects the host's SSH public key into `/root/.ssh/authorized_keys`.
4. Waits for SSH to become reachable on port 22.

Requires `lxd_host_bootstrap` to have run first (or an equivalent, already
initialized LXD host with the target image imported and an SSH keypair
generated).

## Instance type: VM or container

By default every instance is created as a `virtual-machine` (matching the
Kubernetes labs this role was extracted from, which need full kernel
isolation for containerd/kubelet to run inside). Set `lxd_instance_type:
container` (role default, applies to the whole group) or
`lxd_instance_type` as a per-host var in the inventory (overrides the role
default for just that host, so a single group can mix both) to use
lightweight LXD containers instead — useful for lab scenarios that don't
need genuine VM isolation.

**Image format matters:** an LXD image alias is bound to one instance
format — a container image and a virtual-machine image are different
artifacts even when copied from the same remote source. `lxd_host_bootstrap`
only imports the VM variant (`--vm`), matching the labs this role was
extracted from. To actually use `lxd_instance_type: container`, also
override `lxd_image` (globally or per host, same override pattern as
`lxd_instance_type`) to point at an alias imported *without* `--vm`.

## Role Variables

See `defaults/main.yml` for the full list. The per-host inventory
variables this role expects on every member of `lxd_machine_provision_group`
(matching the convention already used across this repository's lab
inventories, so pointing this role at an existing lab's `k8s_nodes` group
needs zero inventory changes):

| Host var | Purpose |
| --- | --- |
| `ansible_host` | Static IPv4 address assigned to the instance |
| `lxd_cpu` | `limits.cpu` |
| `lxd_mem` | `limits.memory` (e.g. `"4GB"`) |
| `lxd_disk` | Root disk size (e.g. `"32GB"`) |
| `lxd_instance_type` (optional) | Overrides `lxd_instance_type` for this host only |

| Role variable | Default | Purpose |
| --- | --- | --- |
| `lxd_machine_provision_group` | `k8s_nodes` | Inventory group to provision |
| `lxd_image` | `k8s-template` | Image alias to clone from |
| `lxd_network` | `lxdbr0` | LXD-managed bridge to attach |
| `lxd_instance_type` | `virtual-machine` | Default instance type for the group |

## Example Playbook

```yaml
- hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - lxd_machine_provision
```

## Testing

```bash
cd ansible/roles/lxd_machine_provision
molecule test
```

Two scenarios are provided under `molecule/`: `default` (VM instances) and
`container` (LXD containers, using its own `prepare.yml` to import a
container-format test image first) — both use the `default` driver (formerly named `delegated`)
against the real host (creating actual LXD instances isn't something a
plain Docker/Podman-based Molecule driver can do), both include Molecule's
built-in `idempotence` step (the role is fully idempotent: the SSH-key-push
task only runs when the key isn't already present, so a second converge
reports zero changes), and both destroy their test instances afterwards.

```bash
molecule test                    # default scenario (virtual-machine)
molecule test -s container       # container scenario
```
