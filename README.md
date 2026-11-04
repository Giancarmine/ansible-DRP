# ansible-DRP

[![CI](https://github.com/Giancarmine/ansible-DRP/actions/workflows/ci.yml/badge.svg)](https://github.com/Giancarmine/ansible-DRP/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Ansible playbooks that turn a fresh Ubuntu machine into a ready-to-work development box.
One playbook installs a baseline set of CLI tools, zsh + Oh My Zsh, Docker + Compose, the
Kubernetes CLI stack, VS Code and Topgrade. It runs against the local machine or a remote host
over SSH.

Tested on **Ubuntu 22.04, 24.04 and 26.04 (64-bit)**. The end-to-end Vagrant test reads the
supported releases from [`ci/ubuntu-versions.yml`](ci/ubuntu-versions.yml), so another release
can be added without touching the playbook.

## What you get

| Role | Installs | Tag |
|---|---|---|
| `base` | APT packages from `packages_apt`, optional pip/snap packages | `base` |
| `ohmyzsh` | zsh, Oh My Zsh, autosuggestions, syntax highlighting, history search | `ohmyzsh`, `shell` |
| `topgrade` | [Topgrade](https://github.com/topgrade-rs/topgrade) | `topgrade` |
| `docker` | `docker.io`, `docker-compose-v2`, daemon config, `docker` group | `docker` |
| `k8s_tools` | kOps, kubectl, Helm, istioctl, kubelogin, kustomize | `k8s_tools`, `kubernetes` + per-tool tags |
| `vscode` | Microsoft VS Code from the official repository | `vscode` |

The `k8s_tools` role also has one tag per tool: `kops`, `kubectl`, `helm`, `istioctl`,
`kubelogin`, `kustomize`.

## Requirements

### Target machine

- Ubuntu 22.04, 24.04 or 26.04, 64-bit (amd64 or arm64). The Vagrant matrix covers all three;
  release assets are published for amd64 and arm64.
- A user with `sudo`. The playbook uses `become` for system changes and works with either
  passwordless sudo or `-K`.
- Outbound access to:
  - `archive.ubuntu.com` and `security.ubuntu.com` for APT packages
  - `github.com` and `objects.githubusercontent.com` for tool releases, Oh My Zsh and plugins
  - `dl.k8s.io` (kubectl) and `get.helm.sh` (Helm)
  - `packages.microsoft.com` for VS Code

### Controller (direct or remote runs)

- Python 3.12 or newer and `git`. The pinned `ansible-core` 2.21.5 requires Python 3.12+, so
  Ubuntu 22.04's Python 3.10 is not enough for the controller. Use a newer host or install
  Python 3.12+.
- Ansible 2.18 or newer. `bootstrap.sh` creates `.venv` and installs the pinned controller from
  `requirements.txt`, so a system Ansible package is not needed.
- The `community.general` 13.5.0 collection, installed by `bootstrap.sh` from `requirements.yml`.
- For local linting: install `requirements-dev.txt` (pinned `ansible-core`, `ansible-lint` and
  `yamllint`).

### Vagrant VM (optional)

The VM path needs Vagrant, libvirt/QEMU, `vagrant-libvirt` and Ansible on the host. The
`Vagrantfile` uses the host controller instead of installing Ansible in the guest, so the same
pinned `ansible-core` runs against every Ubuntu release. Host setup is covered in
[Vagrant VM (libvirt)](#vagrant-vm-libvirt).

## Quick start

```bash
git clone https://github.com/Giancarmine/ansible-DRP.git ~/ansible-DRP
cd ~/ansible-DRP
./bootstrap.sh
source .venv/bin/activate
ansible-playbook ubuntu.yml -K
```

`bootstrap.sh` creates `.venv`, installs the pinned controller from `requirements.txt` and the
required collection, then tells you how to activate it. `-K` asks for the sudo password; omit it
if your user has passwordless sudo.

Preview the changes first:

```bash
ansible-playbook ubuntu.yml --check --diff
```

Check mode is a best-effort preview: tasks that run commands or refresh the APT cache can still
report changes.

### Run only part of the setup

```bash
# Docker and VS Code only
ansible-playbook ubuntu.yml --tags docker,vscode

# Kubernetes CLI stack only
ansible-playbook ubuntu.yml --tags k8s_tools

# One tool
ansible-playbook ubuntu.yml --tags helm

# See every available tag
ansible-playbook ubuntu.yml --list-tags
```

### Provision a remote host

The default inventory targets `localhost`. Create a local inventory for a remote machine:

```ini
# inventory.local
[workstations]
devbox ansible_host=192.0.2.10 ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
```

```bash
ansible-playbook -i inventory.local ubuntu.yml
```

`accept-new` trusts the host key on the first connection and rejects a changed key later.
Remove it once the key is in `known_hosts`. The target user and home directory are read from
Ansible facts (`ansible_facts['user_id']` and `ansible_facts['env']['HOME']`), so the roles follow
the SSH user rather than the user running Ansible. `inventory.local` is git-ignored.

## Configuration

### Ansible settings

`ansible.cfg` keeps runs self-contained and targets the local machine by default:

| Setting | Value | Effect |
|---|---|---|
| `inventory` | `inventory` | Localhost unless another inventory is passed with `-i` |
| `roles_path` | `roles` | Roles resolve from this repository |
| `host_key_checking` | `True` | Host keys are verified. Add `ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'` to the inventory for a first connection |
| `interpreter_python` | `auto_silent` | Finds the target's Python without extra warnings |
| `retry_files_enabled` | `False` | No `*.retry` files are left behind |

### Playbook variables

Defaults live in `group_vars/all.yml`; override them there or with `--extra-vars`.

| Variable | Default | Purpose |
|---|---|---|
| `packages_apt` | CLI baseline (git, curl, zip, `software-properties-common`, …) | APT packages installed by `base` |
| `packages_pip` | `[]` | Optional pip packages |
| `packages_snap` | `[]` | Optional snaps: strings for strict snaps, or `{name, classic}` maps |
| `docker_packages` | `docker.io`, `docker-compose-v2` | Docker packages |
| `docker_daemon` | `{}` | JSON written to `/etc/docker/daemon.json`, only when non-empty |
| `arch` | `amd64` or `arm64` from facts | Release asset architecture; other architectures fail the assert |
| `topgrade_arch` | `x86_64` or `aarch64` from facts | Topgrade asset architecture |
| `release_checksums` | SHA256 per tool and architecture | Verified against every downloaded release asset |
| `kops_version` | `1.36.2` | kOps version |
| `kubectl_version` | `1.37.2` | kubectl version |
| `kubelogin_version` | `1.36.4` | kubelogin version |
| `istioctl_version` | `1.31.3` | istioctl version |
| `helm_version` | `4.3.1` | Helm version |
| `kustomize_version` | `5.8.3` | kustomize version |
| `topgrade_version` | `17.14.1` | Topgrade version |
| `ohmyzsh_version` | pinned commit | Oh My Zsh version installed by the `ohmyzsh` role |
| `ohmyzsh_plugins` | three pinned plugins | Plugin repositories and release tags cloned by `ohmyzsh` |

### Role defaults

These are advanced knobs used by the helper roles. The defaults are usually correct.

| Variable | Default | Purpose |
|---|---|---|
| `custom_apt_arch` | `{{ arch }}` | Architecture segment in APT repository URLs |
| `custom_apt_name` | required | Repository name; also the `.list` filename under `/etc/apt/sources.list.d` |
| `custom_apt_key` | required for signed repositories | `{url, keyring, checksum}`; `url` and `keyring` are required, `checksum` is an optional `sha256:` value verified by `get_url` |
| `custom_apt_repo` | required | Repository line without the `deb` prefix or options |
| `custom_apt_package` | required | Package installed after the repository is added |
| `custom_tools_lib_dir` | `/usr/local/lib` | Destination for extracted tool archives |
| `custom_tools_bin_dir` | `/usr/local/bin` | Destination for tool symlinks |
| `custom_tools_unarchive` | `false` | Force archive extraction instead of a single binary |
| `custom_tools_checksum` | required | SHA256 of the release asset, verified by `get_url` |
| `custom_tools_completion_file` | `~/.config/ansible-drp/completions.zsh` | Native zsh completion snippets sourced by `.zshrc` |
| `k8s_tools_github_url` | `https://github.com` | Base URL for GitHub-hosted releases |

Example override:

```bash
ansible-playbook ubuntu.yml --tags docker \
  --extra-vars '{"docker_daemon":{"log-driver":"local"}}'
```

`custom_apt` writes a `signed-by=<keyring>` option only when a key is configured and an
`arch=<arch>` option only when `custom_apt_arch` is set. It never falls back to the deprecated
`apt_key` module: update the keyring URL instead of importing a key into the global APT trust
store.

### Tag prerequisites

Every per-tool tag installs the package it needs before using it:

- `kubelogin` installs `unzip`, because kubelogin ships as a ZIP archive.
- `zsh`, `ohmyzsh` and `shell` install `zsh` and `git`, because the role clones the framework and
  its plugins from GitHub.

`base` still installs the full CLI baseline, but `--tags kubelogin` or `--tags ohmyzsh` works on
a fresh machine without running `base` first.

## Project layout

```
ansible.cfg                  inventory path, roles path, defaults
inventory                    localhost by default; copy for remote hosts
requirements.txt             pinned Ansible controller
requirements.yml             pinned community.general collection
requirements-dev.txt         pinned lint toolchain (includes requirements.txt)
.ansible-lint                production profile, strict mode
ubuntu.yml                   the playbook
bootstrap.sh                 creates .venv, installs the controller and the collection
group_vars/all.yml           packages, versions, checksums, architecture
ci/ansible-playbook-compat   translates Vagrant's deprecated --inventory-file flag
ci/verify-checksums.py       verifies or updates the pinned release checksums
ci/verify-vm.sh              checks the tools inside the provisioned VM
ci/ubuntu-versions.yml       Ubuntu releases and boxes used by the Vagrant test
roles/
├── base/                    APT/pip/snap packages
├── custom_apt/              adds an APT repository with a signed key
├── custom_tools/            downloads a release, links it into /usr/local/bin
├── docker/                  Docker engine and Compose
├── k8s_tools/               kOps, kubectl, Helm, istioctl, kubelogin, kustomize
├── ohmyzsh/                 zsh, plugins and a managed .zshrc
├── topgrade/                Topgrade binary
└── vscode/                  VS Code repository and package
Vagrantfile                  disposable Ubuntu VM for end-to-end testing
```

`custom_apt` and `custom_tools` are helper roles: the tool roles describe *what* to install and
these two describe *how*.

## Testing

The CI workflow runs on every push and pull request on `ubuntu-24.04`:

```bash
pip install -r requirements-dev.txt
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint                 # production profile, strict mode
ansible-playbook --syntax-check ubuntu.yml
ruby -c Vagrantfile          # Vagrantfile syntax
python ci/verify-checksums.py
actionlint                   # GitHub Actions
shellcheck bootstrap.sh ci/ansible-playbook-compat ci/verify-vm.sh \
  roles/k8s_tools/files/usr/local/bin/kustomize-wrapper
```

A second CI job runs `./bootstrap.sh` on a clean `ubuntu-24.04` runner, activates the generated
`.venv` and runs the playbook syntax check, so the quick start is tested on every push.

The lint toolchain, the `community.general` collection, shellcheck and actionlint are pinned, so
a new upstream release cannot turn `main` red without a deliberate update. Dependabot opens
weekly PRs for the Actions and Python pins; the collection version is bumped in
`requirements.yml`, and the Oh My Zsh commit and plugin tags are bumped in `group_vars/all.yml`.

### Release checksums

`ci/verify-checksums.py` downloads the upstream checksum file for every `(tool, architecture)`
pair in `release_checksums` and fails when a pinned hash differs. Topgrade publishes no checksum
file, so the script downloads and hashes that archive instead.

When you bump a version in `group_vars/all.yml`:

```bash
# Review the new release first, then refresh the pinned hashes.
python ci/verify-checksums.py --update
git diff group_vars/all.yml
python ci/verify-checksums.py   # must pass with no changes
```

The CI job runs the script on every push, so a stale hash is caught before it reaches a VM.

For a real end-to-end run, use the disposable Vagrant VM. It is libvirt-only: the shared folder
uses 9p and the box comes from `ci/ubuntu-versions.yml`, pinned by release and version. The
`cloud-image/ubuntu-24.04` box never receives a cloud-init datasource under libvirt, so it
boots without networking or SSH.

The same run is available as the **Vagrant** workflow. It runs on demand and weekly (Monday
04:00 UTC), because nested virtualization is slow and not always available on hosted runners.
CI validates the playbook statically on every commit; the VM test is the slower end-to-end
check.

### Multiple Ubuntu releases

[`ci/ubuntu-versions.yml`](ci/ubuntu-versions.yml) is the single source of truth for the VM test:

```yaml
versions:
  - release: "26.04"
    box: alvistack/ubuntu-26.04
    box_version: "20260516.1.1"
    enabled: true
```

- The `Vagrantfile` selects the entry named by `UBUNTU_VERSION`, or the last enabled entry when
  the variable is unset. The current default is 26.04.
- The **Vagrant** workflow builds its job matrix from the enabled entries, so each release runs in
  its own job with its own log artifact.
- `enabled: false` keeps a candidate box in the file without running it.

The repository currently enables 22.04, 24.04 and 26.04:
`alvistack/ubuntu-22.04` 20260108.1.1, `alvistack/ubuntu-24.04` 20260108.1.1 and
`alvistack/ubuntu-26.04` 20260516.1.1.

To add another release, download and boot its box, run the full
`vagrant up` / `ci/verify-vm.sh` / `vagrant provision` sequence, then append an entry with
`enabled: true` and push. No playbook, Vagrantfile or workflow change is needed. The playbook
asserts the guest architecture, and the host controller comes from `requirements.txt`, so the
same Ansible version tests every release.

### Automated Vagrant test

Trigger **Actions → Vagrant → Run workflow**, or use the GitHub CLI:

```bash
# Every enabled release in ci/ubuntu-versions.yml
gh workflow run vagrant-up.yml -f verify-idempotence=true

# One release
gh workflow run vagrant-up.yml -f ubuntu-version=24.04
```

The workflow first builds a matrix from `ci/ubuntu-versions.yml`, then runs one job per enabled
release. Each job installs the pinned `ansible-core` on the host, sets up libvirt with the pinned
`vagrant-libvirt` 0.12.2, checks KVM, runs `vagrant up`, executes `ci/verify-vm.sh` inside the
guest, optionally re-provisions and requires `changed=0`, uploads the logs as
`vagrant-logs-ubuntu-<release>`, and destroys the VM. It runs on `ubuntu-24.04` and fails fast if
`/dev/kvm` is missing. GitHub-hosted runners currently expose KVM, but nested virtualization is
not officially supported; use a self-hosted runner with KVM if you need a guaranteed host. A run
takes about 5-10 minutes per release.

Vagrant 2.4 still passes the deprecated `--inventory-file` flag, which ansible-core 2.23 removes.
The `Vagrantfile` sets `ansible.playbook_command` to `ci/ansible-playbook-compat`, which
translates that flag to `--inventory` before running the pinned controller. CI checks the
translation, so a future Ansible bump does not silently break `vagrant up`.

`ci/verify-vm.sh` checks zsh/Oh My Zsh, its pinned commit and plugin tags, and that the managed
`.zshrc` loads, the completion file, Docker + Compose plus daemon access as the login user, every
pinned Kubernetes tool, VS Code and the base packages. The pinned versions are read from
`group_vars/all.yml`, so bumping a version there also updates the assertion.

## Vagrant VM (libvirt)

### 1. Host packages

Install Vagrant 2.3+ from <https://developer.hashicorp.com/vagrant/install>, then the libvirt
stack and the provider plugin. Package names vary by distribution:

```bash
# Debian/Ubuntu
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virtinst
vagrant plugin install vagrant-libvirt --plugin-version 0.12.2

# Arch
sudo pacman -S vagrant libvirt qemu-full virt-install
vagrant plugin install vagrant-libvirt --plugin-version 0.12.2
```

```bash
sudo systemctl enable --now libvirtd
```

KVM must be available (`ls /dev/kvm`). The version is the one used by the Vagrant workflow and
the validated run; newer provider versions may change boot or networking behaviour.

### 2. libvirt access for your user

`vagrant-libvirt` connects to `qemu:///system`. Add your user to the `libvirt` group and start
a new session (or log out and back in):

```bash
sudo usermod -aG libvirt "$USER"
newgrp libvirt
```

If your user still cannot connect, the validated single-user setup also disabled libvirt's
local socket authentication. Only do this on a workstation you control:

```ini
# /etc/libvirt/libvirtd.conf
auth_unix_ro = "none"
auth_unix_rw = "none"
```

```bash
sudo systemctl restart libvirtd
```

### 3. Let QEMU read the 9p share

The `Vagrantfile` shares the repository over 9p, and QEMU reads that folder directly. Its user
must be able to traverse the checkout. The validated setup runs QEMU as the desktop user, which
also needs access to `/dev/kvm` (add the user to the `kvm` group if your distribution restricts
it):

```ini
# /etc/libvirt/qemu.conf
user = "your-user"
group = "your-user"
```

```bash
sudo systemctl restart libvirtd
```

Running QEMU as your user weakens the isolation between host and guest. Use a dedicated test
host if that matters, or move the checkout to a path the default QEMU user (`libvirt-qemu` on
Debian/Ubuntu) can traverse and keep the default `qemu.conf`.

### 4. Firewall

Vagrant creates a NAT network named `vagrant-libvirt` on `virbr1` (`192.168.121.0/24`). If the
host runs UFW, allow the bridge. Without these rules the guest never receives a DHCP lease and
cannot reach the package mirrors:

```bash
WAN=$(ip route show default | awk '{print $5; exit}')
sudo ufw allow in on virbr1
sudo ufw allow out on virbr1
sudo ufw route allow in on virbr1 out on "$WAN"
sudo ufw route allow in on "$WAN" out on virbr1
```

Apply these before the first `vagrant up`; UFW keeps rules for an interface that does not exist
yet. If libvirt assigns a different bridge, check
`virsh -c qemu:///system net-info vagrant-libvirt` and use that name. If the VM is already
stuck waiting for an IP, add the rules and restart networking in the guest
(`sudo systemctl restart systemd-networkd`).

### 5. Run

Install the pinned controller on the host before the first run:

```bash
./bootstrap.sh
source .venv/bin/activate
```

```bash
vagrant up --provider=libvirt
```

The first run downloads the box, boots the VM, mounts the 9p share and runs `ubuntu.yml` from the
host over SSH. The guest only needs its target Python; the host controller version is the one in
`requirements.txt`, so every Ubuntu release is tested with the same Ansible. Allow a few GB
of disk: the box is about 2 GB and the VM disk is sparse. A successful run ends with:

```
PLAY RECAP
ubuntu-26.04 : ok=68  changed=44  unreachable=0  failed=0  skipped=16
```

To test another release, pass its version from `ci/ubuntu-versions.yml`:

```bash
UBUNTU_VERSION=22.04 vagrant up --provider=libvirt
```

Each release gets its own machine name, so switching back and forth does not reuse the previous
release's disk. Re-running is safe and should report `changed=0`:

```bash
vagrant provision
```

Useful commands:

```bash
vagrant ssh                     # shell in the guest
vagrant ssh -c 'docker version'
vagrant halt                    # stop, keep the disk
vagrant destroy -f              # delete the VM and its disk
```

The `Vagrantfile` gives the VM 4 GB of RAM and 4 CPUs; edit `libvirt.memory` and `libvirt.cpus`
if the host has different resources.

The box ships with cloud-init disabled. Vagrant's generated 9p mount metadata is therefore not
applied, so the `mount-9p` provisioner mounts `/vagrant` itself and adds an `fstab` entry before
the Ansible provisioner runs.

### Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Waiting for domain to get an IP address...` for minutes | The host firewall is dropping DHCP or bridge traffic. Apply step 4, then check `virsh -c qemu:///system domifaddr ansible-DRP_ubuntu-<release>` and `journalctl -u libvirtd`. |
| `/vagrant` is empty or missing | 9p permission problem. Run `vagrant ssh -c 'dmesg --level=err,warn'` and verify step 3. |
| `vagrant status` hangs | Another `vagrant` process holds the machine lock. Wait for it, or stop it before retrying. |
| The guest cannot reach the package mirrors | The guest has no egress. Check step 4 with `vagrant ssh -c 'curl -I https://archive.ubuntu.com'`. |
| Guest boots to a `login:` prompt but Vagrant cannot SSH | The box is missing its cloud-init datasource or the network never came up. Use a pinned `alvistack` box from `ci/ubuntu-versions.yml`. |

### Validated environment

Validated end to end on 2026-11-04 with Vagrant 2.4.9, `vagrant-libvirt` 0.12.2, libvirt 12.8.0,
QEMU 11.1.3 and ansible-core 2.21.5. Each release was booted from its pinned `alvistack` box:

| Release | Box | Fresh run | Second provision |
|---|---|---|---|
| 22.04 | `alvistack/ubuntu-22.04` 20260108.1.1 | `ok=68 changed=44 failed=0 skipped=16` | `ok=63 changed=0 failed=0 skipped=21` |
| 24.04 | `alvistack/ubuntu-24.04` 20260108.1.1 | `ok=68 changed=44 failed=0 skipped=16` | `ok=63 changed=0 failed=0 skipped=21` |
| 26.04 | `alvistack/ubuntu-26.04` 20260516.1.1 | `ok=68 changed=44 failed=0 skipped=16` | `ok=63 changed=0 failed=0 skipped=21` |

`ci/verify-vm.sh` passed on all three. The **Vagrant** workflow repeats the same checks on an
`ubuntu-24.04` GitHub-hosted runner in roughly 5-10 minutes per release.

## Notes and safety

- `ohmyzsh` manages `~/.zshrc`. The previous file is backed up next to it as
  `.zshrc.<timestamp>` on the first change.
- Oh My Zsh is pinned to a commit and its plugins to release tags in `group_vars/all.yml`.
  Oh My Zsh self-update is disabled in the managed `.zshrc`, so a provisioned machine stays on
  those versions until you bump the pins. `ci/verify-vm.sh` checks the pins in the VM.
- Adding the user to the `docker` group takes effect after a new login session.
- The playbook installs packages but does not upgrade the system or reboot it.
- The `docker` role restarts Docker only when `daemon.json` changes. With the default empty
  `docker_daemon`, an existing `/etc/docker/daemon.json` is left untouched.
- Release versions are pinned deliberately. Bump the variables in `group_vars/all.yml`; the
  `custom_tools` role downloads the matching amd64/arm64 asset and verifies it against
  `release_checksums`. A version bump must update the version and both architecture hashes.
- `topgrade` uses the same versioned install as the Kubernetes tools, so bumping
  `topgrade_version` replaces the binary instead of leaving the old one in place.
- Shell completions are written to `~/.config/ansible-drp/completions.zsh` as native zsh
  snippets and sourced by `.zshrc` after Oh My Zsh, so `compinit` is already loaded.
- `packages_pip` uses the system Python. On Ubuntu 24.04, populate it only if you also provide a
  venv or pass `--break-system-packages`; the default is empty.
- `packages_snap` accepts strings for strict snaps, or `{name: foo, classic: true}` maps for
  classic confinement.
- `copyq` is a GUI application and `unrar` comes from multiverse. Trim `packages_apt` for a
  headless server or a minimal image without those components.
- `host_key_checking` is enabled. Use `StrictHostKeyChecking=accept-new` in the inventory for the
  first connection to a new host.
- The Vagrant box is pinned by release and version in `ci/ubuntu-versions.yml` for the same
  reason. Vagrant Cloud does not publish a checksum for these boxes, so the version pin is the
  only integrity control. To move to a newer box, update that file deliberately and re-run the
  end-to-end test before committing.
- Test on a VM or a disposable host before running against a machine you care about.
- The Vagrant workflow changes the host, not just the VM: libvirt group membership, the QEMU
  user in `/etc/libvirt/qemu.conf`, optional socket authentication in `/etc/libvirt/libvirtd.conf`
  and the UFW rules for `virbr1`. Revert what you do not want to keep after testing.
- `vagrant destroy -f` removes the VM and its disk, but leaves the downloaded box in
  `~/.vagrant.d/boxes`. Remove it with `vagrant box remove alvistack/ubuntu-24.04` if you no
  longer need it.

## Inspired by

- <https://github.com/arcones/my-DRP>
- <https://pbassiner.github.io/blog/automating_my_dev_setup.html>
- <https://github.com/pbassiner/dev-env>
- <https://gist.github.com/komuw/b3b5d24977d4df7bd549#gistcomment-3741919>
- <https://github.com/Preetam/transverse/tree/master/.github/actions/ansible>

## License

[MIT](LICENSE)
