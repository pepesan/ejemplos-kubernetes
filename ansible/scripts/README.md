# Scripts

Standalone test/utility scripts that don't belong to any single lab or role.

## `test_lxd_host_bootstrap_distros.sh`

Smoke-tests `lxd_host_bootstrap` against every distro it claims to support (`ansible/roles/lxd_host_bootstrap/meta/main.yml`: Ubuntu 24.04/26.04, Debian 12/13, Rocky Linux 9, Fedora 43/44 — Rocky 10 isn't tested live since no LXD image is published for it yet). For each distro:

1. Imports a container-format test image, if not already present (`00_prepare_images.yml`).
2. Creates a plain, throwaway LXD container and ensures `python3` is present — Debian's minimal container images don't ship it, Ubuntu's/Rocky's/Fedora's do (`01_provision.yml`).
3. Runs `lxd_host_bootstrap` against it over the `community.general.lxd` connection plugin (`lxc exec`, no SSH — `02_bootstrap.yml`), skipping two categories of task that don't apply to a remote-target test the way this role is actually used in practice (`connection: local`, on the very machine you're bootstrapping):
   - `requires_virtualization` (the `lxd_init`/`base_image` tasks): installing a nested LXD daemon inside a test container isn't necessary to prove the apt/snap/kernel-module logic works on that distro.
   - `requires_ansible_control_node` (the Ansible Galaxy collections task): assumes `ansible-galaxy` is already on the target, trivially true when the target IS the control node but not for a genuinely separate/fresh remote target like these test containers.
4. Deletes every test container, whether the run succeeded or failed (`03_destroy.yml`, run via a `trap ... EXIT`).

Deliberately does **not** reuse `lxd_machine_provision` for step 2: that role exists to provision instances the labs will actually SSH into (and already has its own Molecule coverage for that), whereas this test only needs a plain container reachable via `lxc exec` — no SSH keys, no static IP.

### Usage

```bash
cd ansible/scripts
./test_lxd_host_bootstrap_distros.sh
```

No `sudo` required: creating/deleting LXD containers only needs membership in the `lxd` group, and `lxd_host_bootstrap`'s own privileged tasks run *inside* the disposable test containers, not on the host running this script.

## `test_instalar_ansible_distros.sh`

Smoke-tests `ansible/base/00_instalar_ansible.sh` (the pipx-based Ansible installer) against the 2 latest stable releases of Ubuntu, Debian, Rocky Linux, Fedora and openSUSE — same distro scope as `lxd_host_bootstrap`, plus openSUSE. Rocky only has one release tested live (9: no LXD image for 10 yet, same blocker as above). openSUSE tests Leap 16.0 + Tumbleweed instead of two Leap releases, since no 15.x LXD image is published anymore either.

For each distro, launches a plain throwaway container (no VM, no SSH — just `lxc exec`), pushes the installer script in, runs it as root with `SKIP_CHECK_REQUISITOS=true` (there's no real LXD/`lxc` inside the test container, so the installer's final `check_requisitos.yml` step doesn't apply here), and checks `ansible-playbook --version` works afterwards. Always deletes every test container on exit, via `trap ... EXIT`, whether the run succeeded or not.

This test is what proved `00_instalar_ansible.sh` needs `pipx install --include-deps` rather than plain `pipx install`: on Rocky Linux 9 (system Python 3.9), pip resolves an older `ansible` release whose own package only declares `ansible-community` as a console script, delegating `ansible-playbook`/`ansible-galaxy`/etc. to its `ansible-core` dependency — and pipx doesn't expose a dependency's scripts unless asked to. It also confirmed openSUSE needs an explicit `python3` install first (its container images don't ship it) and has no stable `pipx` package name across releases (it's versioned with the system Python, e.g. `python313-pipx`), so the installer falls back to `python3 -m ensurepip --user && python3 -m pip install --user pipx` there.

### Usage

```bash
cd ansible/scripts
./test_instalar_ansible_distros.sh
```

No `sudo` required, for the same reason as the bootstrap smoke test above.
