# 🧩 Roadmap and Status of the Roles

Backlog and status of the reusable Ansible roles in `ansible/roles/`. See [`../base/PLAN.md`](../base/PLAN.md)
for the base labs' roadmap, or [`../PLAN.md`](../PLAN.md) for the repository overview.

After completing the 14 base labs (01-14), a fair amount of duplicated or near-identical logic between
them would fit as standalone Ansible roles. The existing labs have NOT been migrated to use these roles
yet (explicit decision: build the roles standalone first, migrate later).

## Status

- ✅ **`lxd_machine_provision`** (implemented and validated with real Molecule, 2026-07-18): provisions LXD instances — **VMs or containers, indistinctly** (`lxd_instance_type`, per group or per host) — with given specs (CPU/RAM/disk), independent of whatever gets installed inside afterwards. Faithfully reproduces `02_crear_nodos.yml` (creation, waiting for the LXD agent, injecting the host's SSH key, waiting for SSH), generalizing the instance type (the original only ever created VMs). A full `molecule test` (syntax, converge, native `idempotence`, verify, destroy) passes in both scenarios (`default`=VM, `container`), leaving no residue.
- 🟢 **`lxd_host_bootstrap`** (implemented and validated across every supported distro, 2026-07-18): prepares the physical host (apt packages, Galaxy collections, kernel modules, LXD/kubectl/helm via snap, `lxd init` for network+storage+profile, base image). Faithfully reproduces `ansible/base/00_bootstrap_host_lxd.yml`, reorganized into separate task files with the hardcoded values turned into `defaults/main.yml`. Real bugs found and fixed:
  1. `lxd_host_user` and the tasks that relied on "whoever connects" (`become: false`) assumed the play is invoked as a regular user escalating with `become: true` — assuming in tests that the whole process already runs as root (`sudo -E molecule test`, no interactive password prompt) broke that assumption, and the SSH key/Galaxy collections ended up under `/root` instead of the real user. Fixed by resolving `lxd_host_user` from `SUDO_USER` (falling back to the connecting user) and explicitly targeting those tasks at it via `become_user`.
  2. The classic snap mount symlink (`/snap` → `/var/lib/snapd/snap`, needed on Debian, already present on Ubuntu) failed on **every** distro, not just Debian: `/var/lib/snapd/snap` doesn't exist yet immediately after installing the `snapd` package (only snapd itself creates it, on first run), and `ansible.builtin.file`'s `link` state refuses to create a symlink to a target that doesn't exist yet unless `force: true` is set.
  3. Loading a kernel module is inherently a host/VM-level concern — a container shares its host's kernel, and the `modprobe` executable itself may not even be present in a minimal container image (missing on one Debian 12 test container, while it happened to succeed on the others only because that module was already loaded at the host level and visible inside the container). Tagged `requires_virtualization` (same tag as `lxd_init`/`base_image`) so a container-based test can skip it.
  4. The Ansible Galaxy collections task assumes `ansible-galaxy` is already present on the target — trivially true for this role's real usage (`connection: local`, the same machine already running `ansible-playbook` to get this far), but not for a genuinely separate/fresh remote target. Tagged `requires_ansible_control_node` so a remote-target test can skip it explicitly instead of failing on an assumption the role was never meant to make in its normal (local) usage.
  5. Installing/running `snapd` itself (squashfs mounts, AppArmor) is generally unreliable inside a lightweight container regardless of distro — confirmed live: even the classic-mount symlink step failed on every distro's test container with `"/snap is not empty, refusing to convert it"` (LXD appears to inject a `/snap` entry into containers on its own). Tagged the whole `snap_packages.yml` (symlink + the snap installs themselves) `requires_virtualization` too.
  6. The `lxd` group (added to in `user_group.yml`) is created by the `lxd` snap package itself, so it doesn't exist once `snap_packages` is skipped — Ubuntu's base images happen to predefine it anyway, but Debian's don't (confirmed live: this task only failed on the Debian test containers, with `"Group lxd does not exist"`). Tagged `requires_virtualization` as well.
  7. Rocky Linux 9 support (added 2026-07-18): a live probe against a throwaway Rocky 9 test container confirmed `ansible.builtin.apt` (used directly for the package-install task) doesn't exist at all on RHEL-family systems — it failed immediately, with Ansible even attempting to auto-install a bogus `python3-apt` dependency first. Fixed by switching to the generic `ansible.builtin.package` module (auto-detects `dnf`) and splitting the package list per OS family (`vars/Debian.yml`, `vars/RedHat.yml` — identical lists except `python3-yaml` is `python3-pyyaml` on RHEL-family), loaded via `include_vars`. Rocky/RHEL/CentOS also need EPEL enabled first (`epel-release`, guarded to exclude Fedora, whose own repos already carry everything needed) for `snapd`/`python3-kubernetes`/`python3-jsonpatch` to resolve. Fedora 43/44 and Rocky 9 declared in `meta/main.yml`; Rocky 10 also declared for forward-compatibility, but has no published LXD image yet (`images:rockylinux` only lists 8 and 9) so it isn't tested live.

  Validated end to end via a dedicated multi-distro smoke test (`ansible/scripts/test_lxd_host_bootstrap_distros.sh` — see [`../scripts/README.md`](../scripts/README.md)): spins up one throwaway LXD container per distro declared in `meta/main.yml` (Ubuntu 24.04/26.04, Debian 12/13, Rocky Linux 9, Fedora 43/44), connects via the `community.general.lxd` connection plugin (`lxc exec`, no SSH — real usage is always `connection: local`, so SSH was never actually part of the role's requirements), and runs the role skipping everything tagged `requires_virtualization`/`requires_ansible_control_node`. **Passes cleanly (`failed=0`) on all seven distros**, covering the genuinely distro-sensitive logic: the SSH keypair task, the package install via `ansible.builtin.package` (confirming `snapd`/`curl`/`python3-kubernetes`/`python3-jsonpatch`/`python3-yaml`(`-pyyaml` on RHEL-family) all resolve on every family, apt or dnf), the EPEL-enablement step (only runs on Rocky, correctly skipped everywhere else including Fedora), and kernel module config persistence. The skipped tasks (snap/LXD install, `lxd_init`, base image import, the `lxd` group, Galaxy collections) remain to be validated for real via `molecule test` with actual `sudo` — see below.
- ⬜ **`k8s_ha_cluster`**: given a set of IPs/machine pools, a number of managers/workers and per-pool requirements, stands up the full HA cluster (kube-vip VIP) with swappable options for CNI (Cilium/Flannel), CSI/storage (Longhorn/Rook Ceph/external) and Headlamp (toggleable, as one more cluster-install option rather than a separate role).
- ⬜ **`percona_operator`**: generic "add Helm repo + install operator + wait for rollout" pattern, parameterized by the operator's name (`pxc-operator`, `pg-operator`, `psmdb-operator`).
- ⬜ **`generated_secret`**: the repeated "generate a credential if it doesn't already exist, save it to a local file with `0600` permissions, never print it" pattern (PXC, MongoDB, Vault and `vault_admin` passwords...).
- ⬜ **`k8s_node_scale_cycle`**: safely add/join a new node to the cluster and drain it on removal — in particular the workaround for Longhorn's `instance-manager` PDB before a `kubectl drain`, the most-repeated lesson learned across the whole repository (labs 03, 10-13).

## Possible improvements (competing roles reviewed)

Similar published roles reviewed: [`juju4/ansible-lxd`](https://galaxy.ansible.com/juju4/lxd),
[`plumelo/ansible-role-lxd`](https://github.com/plumelo/ansible-role-lxd),
[`tideops/ansible-role-kubernetes`](https://github.com/tideops/ansible-role-kubernetes).

- **`lxd_host_bootstrap`/`lxd_machine_provision`**: no concrete improvement identified. `juju4/ansible-lxd`
  and `plumelo/ansible-role-lxd` are both more limited than our two roles (they only install LXD and
  networking, with no base-image management, no VM/container selection, no SSH key injection) — nothing
  worth adopting there.
- **`k8s_ha_cluster` (future)**: `tideops/ansible-role-kubernetes` covers a similar scope (kubeadm HA +
  kube-vip + selectable CNI/storage), but uses a simple per-component on/off boolean pattern
  (`install_longhorn`, `install_nginx_ingress`...), not real swappable implementation selection. For
  `k8s_ha_cluster`, a pattern of conditional task files indexed by the chosen component's name is
  preferred (e.g. `cni: cilium` vs `cni: flannel` loading different task files, not just toggling one
  fixed implementation on/off) — more flexible, and truer to the original "swappable CNI/CSI options"
  goal. This is the only concrete takeaway from the competing-role review, and it applies to a role not
  implemented yet, not to the two already built.

## Language

Unlike the 14 base labs (in Spanish), the roles in `ansible/roles/` — and everything else in that
directory, including this file — are written entirely in English (code, comments, documentation and
tests): an explicit user instruction, deliberately different from the rest of the repository's
convention.

## Galaxy namespace — to revisit before publishing

Both roles' `meta/main.yml` use `namespace: ejemplos_kubernetes` as a placeholder
(Molecule/`ansible-compat` requires some namespace to compute the role's fully qualified name, even if
it's never actually published). If these are ever published for real on Ansible Galaxy, replace it with
the publishing account's real namespace.

## Test plan — Molecule

Using the `default` driver (renamed from `delegated` in Molecule 26.x) against the real host (neither
`lxd_host_bootstrap` nor `lxd_machine_provision` can be tested representatively inside an isolated
Docker/Podman container, since both depend on real virtualization). Each role includes Molecule's
native `idempotence` step in its `test_sequence` — no "always changed" step is accepted as an
exception; for `lxd_machine_provision` this required fixing the SSH key injection to check the existing
content before pushing it, instead of assuming the "always changed" pattern that is accepted elsewhere
in the repo (e.g. Headlamp's `force_update`) — an explicit user decision to require real, verified
idempotency in the new roles. `lxd_machine_provision` has two Molecule scenarios (`default` for VM,
`container` for container — the latter with its own `prepare.yml` to import a container-format image,
since an LXD alias is bound to one format, VM or container, never both).

**Molecule was installed during this session** (`pipx install molecule` + `molecule-plugins[docker]`,
though the driver actually used is `default`/formerly `delegated`, included in core) and `molecule test`
runs for real — not a manual approximation. Adjustments that were needed to make it work:
- `meta/main.yml` needs an explicit `namespace`.
- Each `molecule.yml`'s `provisioner.env.ANSIBLE_ROLES_PATH` must point at
  `${MOLECULE_PROJECT_DIRECTORY}/..` (the parent `ansible/roles/`) so `roles: [...]` resolves without
  installing the role as a collection.

`lxd_host_bootstrap`'s own Molecule scenario is written but still needs a real live `molecule test` run
by the user (it needs `sudo`, unavailable non-interactively in this session) — validated so far via
`--syntax-check`, inspection, and the multi-distro container smoke test described above (which covers
the same OS-package-level logic via a different, `sudo`-free path).
