# Scripts

Standalone test/utility scripts that don't belong to any single lab or role.

## `test_lxd_host_bootstrap_distros.sh`

Smoke-tests `lxd_host_bootstrap` against every distro it claims to support (`ansible/roles/lxd_host_bootstrap/meta/main.yml`: Ubuntu 24.04/26.04, Debian 12/13, Rocky Linux 9, Fedora 43/44, openSUSE Leap 16.0/Tumbleweed — Rocky 10 isn't tested live here since no *container*-format LXD image is published for it yet, only the locally-built VM one used by `test_instalar_ansible_distros.sh` below). For each distro:

1. Imports a container-format test image, if not already present (`00_prepare_images.yml`).
2. Creates a plain, throwaway LXD container and ensures `python3` is present — Debian's minimal container images don't ship it, the others do (`01_provision.yml`).
3. Runs `lxd_host_bootstrap` against it over the `community.general.lxd` connection plugin (`lxc exec`, no SSH — `02_bootstrap.yml`, with `--forks 10` so all 9 distro containers run in a single parallel batch instead of two — Ansible's default of 5 forks would otherwise split them), skipping two categories of task that don't apply to a remote-target test the way this role is actually used in practice (`connection: local`, on the very machine you're bootstrapping):
   - `requires_virtualization` (the `lxd_init`/`base_image` tasks, plus the whole LXD/kubectl/helm install step): installing a nested LXD daemon inside a test container isn't necessary to prove the apt/snap/zypper/kernel-module logic works on that distro.
   - `requires_ansible_control_node` (the Ansible Galaxy collections task): assumes `ansible-galaxy` is already on the target, trivially true when the target IS the control node but not for a genuinely separate/fresh remote target like these test containers.
4. Deletes every test container, whether the run succeeded or failed (`03_destroy.yml`, run via a `trap ... EXIT`).

Deliberately does **not** reuse `lxd_machine_provision` for step 2: that role exists to provision instances the labs will actually SSH into (and already has its own Molecule coverage for that), whereas this test only needs a plain container reachable via `lxc exec` — no SSH keys, no static IP.

This test is what caught openSUSE's base image shipping neither `ssh-keygen` nor a `cryptography` library new enough for the `openssh_keypair` module's fallback — the very first task in the role failed with `"Cannot find either the OpenSSH binary in the PATH or cryptography >= 3.3 installed on this system"` until `openssh-clients` was installed first, guarded to only run on `os_family == 'Suse'` since every other supported distro's base image already carries it.

### Usage

```bash
cd ansible/scripts
./test_lxd_host_bootstrap_distros.sh
```

No `sudo` required: creating/deleting LXD containers only needs membership in the `lxd` group, and `lxd_host_bootstrap`'s own privileged tasks run *inside* the disposable test containers, not on the host running this script.

## `test_instalar_ansible_distros.sh`

Smoke-tests `ansible/base/00_instalar_ansible.sh` (the pipx-based Ansible installer) against the 2 latest stable releases of Ubuntu, Debian, Rocky Linux (9 and 10), Fedora and openSUSE (Leap 16.0 + Tumbleweed instead of two Leap releases, since no 15.x LXD image is published anymore either).

For every distro except `rocky-10`, launches a plain throwaway **container** (no VM, no SSH — just `lxc exec`). `rocky-10` is the one exception: no LXD image (container *or* VM) is published for it yet at all, so it's launched as a **VM** (`--vm`) from the local `rockylinux/10/vm` image built by `build_rocky10_lxd_image.sh` (see `ansible/roles/lxd_machine_provision/README.md`, "Building images not yet published") — run that script first if the image isn't imported yet (`lxc image list rockylinux/10/vm`). Either way, the script then pushes the installer script in, runs it as root with `SKIP_CHECK_REQUISITOS=true` (there's no real LXD/`lxc` inside the test instance, so the installer's final `check_requisitos.yml` step doesn't apply here), and checks `ansible-playbook --version` works afterwards. Always deletes every test instance on exit, via `trap ... EXIT`, whether the run succeeded or not.

This test is what proved `00_instalar_ansible.sh` needs `pipx install --include-deps` rather than plain `pipx install`: on Rocky Linux 9 (system Python 3.9), pip resolves an older `ansible` release whose own package only declares `ansible-community` as a console script, delegating `ansible-playbook`/`ansible-galaxy`/etc. to its `ansible-core` dependency — and pipx doesn't expose a dependency's scripts unless asked to. It also confirmed openSUSE needs an explicit `python3` install first (its container images don't ship it) and has no stable `pipx` package name across releases (it's versioned with the system Python, e.g. `python313-pipx`), so the installer falls back to `python3 -m ensurepip --user && python3 -m pip install --user pipx` there.

### Usage

```bash
cd ansible/scripts
./test_instalar_ansible_distros.sh
```

No `sudo` required, for the same reason as the bootstrap smoke test above.
