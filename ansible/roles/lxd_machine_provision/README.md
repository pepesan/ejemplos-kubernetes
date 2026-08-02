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

## Requirements

- Any LXD host already bootstrapped by `lxd_host_bootstrap` (Ubuntu 24.04/26.04,
  Debian 12/13, Rocky Linux 9/10, Fedora 43/44, or openSUSE Leap 16.0/Tumbleweed).
  This role itself has no distro-specific logic — it only calls `lxc` and
  generic Ansible modules — so it works identically on all of them; the
  platform constraint comes entirely from `lxd_host_bootstrap`.

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

## Building images not yet published (e.g. Rocky Linux 10)

`lxd_host_bootstrap`/`k8s_ha_cluster` support Rocky Linux 9 by copying the publicly published
`images:rockylinux/9` remote image. Rocky Linux 10 has no published LXD/Incus image yet (re-confirmed
2026-08-02: `lxc image list images:rockylinux/10` returns nothing, only Rocky 8/9 are published), so
using it here means building one locally first and importing it with `lxc image import ... --alias
<alias>` so `lxd_image`/`lxd_instance_type` can point at it exactly like any other alias.

**Status: resolved, both image types.** `ansible/scripts/build_rocky10_lxd_image.sh [arch] [vm|container]`
builds and imports the image end-to-end; verified live 2026-08-02 for both:

- `./build_rocky10_lxd_image.sh x86_64 vm` → imports `rockylinux/10/vm`. Booted, confirmed
  `lxc exec`/`systemctl is-system-running` → `running`.
- `./build_rocky10_lxd_image.sh x86_64 container` → imports `rockylinux/10`. Needs none of the three
  VM-specific workarounds below (no agent to start, since a container shares the host kernel
  directly) — booted, confirmed `systemctl is-system-running` → `running` and `dnf` resolves
  repos/DNS fine. Set `lxd_instance_type: container` alongside `lxd_image: rockylinux/10` to use it
  with this role.

It was first attempted 2026-07-18 and blocked on a genuine upstream `distrobuilder` bug at the time —
see git history of this file for that session's diagnostics (wrong build subcommand, `btrfs-progs`
dependency, a truncated-download red herring, and the GPG bootstrap failure). Three real problems had
to be worked around to get from there to a working VM image, all confirmed live rather than assumed:

1. **The `distrobuilder` snap is stale on both channels.** `latest/edge` is pinned to a build from
   2025-06-18, which predates the upstream commit that actually added Rocky 10 support
   (2025-08-03, "rockylinux: Add RockyLinux 10 support") — that commit is what fixes the GPG bootstrap
   failure from the 2026-07-18 session, by adding `--nogpgcheck` to `distrobuilder`'s internal `dnf
   --installroot` bootstrap step for release 10 ("since rpmkeys isn't available" in the install ISO).
   There's no way to get this fix from the snap store today, so the script builds `distrobuilder` from
   source (Go toolchain) instead of using the snap.
2. **The upstream `rockylinux.yaml` (`lxc/lxc-ci`) only wires up its `incus-agent` generator for
   Incus's virtio-serial port name** (`org.linuxcontainers.incus`). A host running Canonical LXD (not
   Incus) names that same port `org.linuxcontainers.lxd` — confirmed by reading the actual
   `-readconfig` `qemu.conf` LXD generates for a running VM. Without a matching udev rule, the rule
   that starts `incus-agent.service` never fires: the VM boots with a working network, but `lxc
   exec`/`lxc list` IPv4 forever report "LXD VM agent is not currently running". Fixed by appending a
   second udev rule aliasing the LXD port name to the same `incus-agent.service`.
3. **Even with the udev rule firing, the service still failed to start.** Confirmed by temporarily
   overriding the agent-setup script to trace to the VM's serial console: the 9p mount fails (this
   Rocky 10 build has no `9pnet_virtio` kernel module — 9p support isn't in the minimal variant), but
   the `virtiofs` fallback mount succeeds and copies the config-drive contents fine. The real failure
   is that **LXD's own config drive ships the agent binary as `lxd-agent`, not `incus-agent`** (that
   naming comes from Incus's own image definition/unit), so `incus-agent.service`'s
   `ExecStart=/run/incus_agent/incus-agent` finds nothing. Fixed by symlinking `incus-agent` to
   `lxd-agent` in the setup script when only the latter is present, so the same image boots correctly
   under either LXD or Incus.

None of this required patching `distrobuilder` itself — every fix is either building it fresh from
source or a small addition to the local copy of the image definition YAML, both automated by the
script. All three findings are specific to whatever `distrobuilder`/LXD versions were current on
2026-08-02 — re-verify them (don't just re-run blindly) if either project has moved on since.

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
| `lxd_extra_disk` (optional) | Attaches a second, raw block device (e.g. `"20GB"`) beyond the root disk — for anything that needs its own storage device (e.g. a Ceph OSD's backing disk), not just more root disk space. Off by default; only created/attached for hosts that define it. |

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
