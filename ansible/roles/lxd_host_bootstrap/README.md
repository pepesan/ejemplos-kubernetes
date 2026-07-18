# lxd_host_bootstrap

Prepares a physical (or virtual) host to run LXD-based Kubernetes labs:

- Installs system dependencies (`snapd`, `curl`, the Python libraries the
  `kubernetes.core` Ansible collection needs) and the required Ansible
  Galaxy collections (`community.general`, `kubernetes.core`).
- Loads and persists the kernel modules needed by the container runtime and
  CNI bridging (`overlay`, `br_netfilter`).
- Installs LXD, `kubectl` and `helm` via snap.
- Initializes LXD (network bridge, storage pool, default profile) via
  `lxd init --preseed`, only if it isn't initialized yet.
- Adds the host user to the `lxd` group.
- Copies and aliases the base VM image (`ubuntu:26.04` by default) that
  every lab instance is later cloned from (see the `lxd_machine_provision`
  role).
- Generates the SSH keypair used to reach every LXD instance as root.

This role is idempotent: re-running it on an already-bootstrapped host is a
no-op for every task except the ones that are inherently non-idempotent by
design (`community.general.ansible_galaxy_install` with `state: latest`
always re-checks upstream).

## Requirements

- Ubuntu 26.04 host with `sudo`/root access.
- Real virtualization support for the `lxd_init` and `base_image` tasks
  (tagged `requires_virtualization`) — these cannot run inside a plain,
  unprivileged container. See `molecule/default/` for how this is tested.

## Role Variables

See `defaults/main.yml` for the full list with their default values. The
most relevant ones:

| Variable | Default | Purpose |
| --- | --- | --- |
| `lxd_host_user` | `$USER` | User added to the `lxd` group |
| `lxd_ssh_key_path` | `~/.ssh/id_ed25519` | Keypair used to reach LXD instances |
| `lxd_network_name` | `lxdbr0` | LXD-managed bridge name |
| `lxd_network_subnet` | `10.207.154.1/24` | Bridge subnet |
| `lxd_storage_pool_name` | `default` | LXD storage pool name |
| `lxd_base_image_remote` | `ubuntu:26.04` | Remote image to clone from |
| `lxd_base_image_alias` | `k8s-template` | Local alias for the imported image |

## Example Playbook

```yaml
- hosts: localhost
  become: true
  roles:
    - lxd_host_bootstrap
```

## Testing

```bash
cd ansible/roles/lxd_host_bootstrap
sudo -E molecule test
```

See `molecule/default/` — it uses the `delegated` driver against the real
host (this role provisions the very virtualization layer Molecule's usual
container-based drivers would need, so testing it inside a container isn't
representative). The scenario assumes it's run as root already (hence
`sudo -E`, not `--ask-become-pass`/interactive escalation) — it sets
`become: false` in `converge.yml`, purely a local/CI testing convenience.
Real usage of this role (e.g. `bootstrap_host.sh`) is unaffected: it still
runs as a regular user with `become: true` and prompts for the sudo
password. The built-in `idempotence` step is included in the test sequence
and is the primary idempotency check, matching this repository's general
two-pass validation discipline (see `.agents/rules/idempotencia.md`).
