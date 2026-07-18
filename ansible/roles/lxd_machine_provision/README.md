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

- Ubuntu 24.04/26.04 or Debian 12 (bookworm)/13 (trixie) as the LXD host.
  This role itself has no distro-specific logic — it only calls `lxc` and
  generic Ansible modules — so it works identically on both; the platform
  constraint comes entirely from `lxd_host_bootstrap`.

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
`images:rockylinux/9` remote image. Rocky Linux 10 has no published LXD/Incus image yet, so using it
here means building one locally first, via [`distrobuilder`](https://github.com/lxc/distrobuilder)
(`sudo snap install distrobuilder --classic`), then importing it with `lxc image import ... --alias
rockylinux/10` (container) / `--alias rockylinux/10/vm` (VM) so `lxd_image`/`lxd_instance_type` can
point at it exactly like any other alias.

**Status: blocked on an upstream `distrobuilder` bug, not something fixable from this repo.**
Attempted live 2026-07-18, real findings from real diagnostics at every step (no assumptions):

1. **`distrobuilder build-lxd` doesn't exist** in current versions — LXD-compatible images are built
   with `distrobuilder build-incus` (despite the name, it works fine with the `lxc` CLI; its own docs
   confirm `--import-into-incus` literally shells out to `lxc image import`). The image definition
   YAML (`rockylinux.yaml`) also isn't in the `distrobuilder` repo itself anymore — it moved to
   `lxc/lxc-ci`'s `images/` directory.
2. **VM builds need `btrfs-progs`** installed on the host (`distrobuilder` checks for the `btrfs`
   binary before building a `--vm` qcow2 image) — a real, satisfiable dependency, not a bug.
3. **The install ISO's `install.img` failed to mount** (`mount: ... cannot read superblock`,
   confirmed via `strace` to be `mount("/dev/loopN", ..., "squashfs", ...) = -1 EIO`). Initially looked
   like `distrobuilder` hardcoding `squashfs` when Rocky 10 (RHEL 10 family) actually ships an EROFS
   image — but that turned out to be a **red herring**: the real cause, confirmed by comparing the
   downloaded ISO's actual byte size against the real `Content-Length` from Rocky's mirror
   (`2072444928` bytes expected, only `268467918` present), was a **truncated download** — two
   `distrobuilder`/`wget` processes had been run close together and both written to the exact same
   shared cache path (`/tmp/distrobuilder/rockylinux-10-x86_64/...iso`) concurrently, corrupting it.
   Fixed by deleting the cache and downloading once, sequentially, with `wget` (verified byte-for-byte
   against the real `Content-Length` before rebuilding) — **do not run more than one `distrobuilder`
   build against the same not-yet-downloaded source at once.**
4. **With a verified-complete ISO, the build gets much further** (real `dnf --installroot` package
   resolution and download against Rocky's actual `BaseOS` repo) but then fails GPG verification on
   every package: `distrobuilder`'s `rockylinux-http` downloader only successfully imports the
   **Rocky 9** signing key (`0x350D275D`, "Release key 2022") into its internal bootstrap keyring, not
   the Rocky 10 key — even though the image definition embeds all three (8/9/10) as armored blocks.
   This happens inside `distrobuilder`'s own **hardcoded internal bootstrap step** (the very first
   `dnf --installroot=/rootfs install basesystem Rocky-release yum`, before any of the YAML's own
   `packages:`/`source.skip_verification` config even applies) — there is no user-facing option to
   disable GPG checking for that specific internal call, confirmed against `distrobuilder`'s own
   `source`/`packages` reference docs. Tried both the `latest/stable` (3.1, Oct 2024) and `latest/edge`
   (git snapshot, mid-2025) snap channels — same failure on both, so this isn't fixed even in the
   newest available build as of this session.

**Bottom line**: building a genuinely correct Rocky 10 image with `distrobuilder` as it currently
stands isn't possible without either patching `distrobuilder` itself or manually re-implementing its
bootstrap step outside the tool (`dnf --installroot --nogpgcheck` by hand, then `distrobuilder
pack-lxc`/`pack-incus` on the pre-built rootfs) — real, substantial extra work, not attempted here.
Rocky 10 stays unsupported in `k8s_ha_cluster`/`lxd_host_bootstrap` until either `distrobuilder` fixes
this upstream or a published image appears on the public remote.

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
