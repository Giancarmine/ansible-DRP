# ansible-DRP

[![CI](https://github.com/Giancarmine/ansible-DRP/actions/workflows/ci.yml/badge.svg)](https://github.com/Giancarmine/ansible-DRP/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Ansible playbooks that turn a fresh Ubuntu machine into a ready-to-work development box.
One playbook installs a baseline set of CLI tools, zsh + Oh My Zsh, Docker + Compose, the
Kubernetes CLI stack, VS Code and Topgrade. It runs against the local machine or a remote host
over SSH.

Tested on **Ubuntu 24.04 (64-bit)**.

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

- Ubuntu 24.04, 64-bit (amd64 or arm64).
- A user with `sudo`. The playbook uses `become` for system changes and works with either
  passwordless sudo or `-K`.
- Outbound access to:
  - `archive.ubuntu.com` and `security.ubuntu.com` for APT packages
  - `ppa.launchpadcontent.net` when Vagrant installs Ansible inside the guest
  - `github.com` and `objects.githubusercontent.com` for tool releases, Oh My Zsh and plugins
  - `dl.k8s.io` (kubectl) and `get.helm.sh` (Helm)
  - `packages.microsoft.com` for VS Code

### Controller (direct or remote runs)

- Ansible 2.16 or newer (`bootstrap.sh` installs the Ubuntu package if Ansible is missing).
- `git` and `python3`.
- The `community.general` collection, installed by `bootstrap.sh` from `requirements.yml`.

### Vagrant VM (optional)

The VM path needs Vagrant, libvirt/QEMU and `vagrant-libvirt` on the host. Host setup is
covered in [Vagrant VM (libvirt)](#vagrant-vm-libvirt).

## Quick start

```bash
git clone https://github.com/Giancarmine/ansible-DRP.git ~/ansible-DRP
cd ~/ansible-DRP
./bootstrap.sh
ansible-playbook ubuntu.yml -K
```

`bootstrap.sh` installs Ansible and the required collection if they are missing. `-K` asks for
the sudo password; omit it if your user has passwordless sudo.

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
devbox ansible_host=192.0.2.10 ansible_user=ubuntu
```

```bash
ansible-playbook -i inventory.local ubuntu.yml
```

The target user and home directory are read from Ansible facts (`ansible_user_id`,
`ansible_env.HOME`), so the roles follow the SSH user rather than the user running Ansible.
`inventory.local` is git-ignored.

## Configuration

### Ansible settings

`ansible.cfg` keeps runs self-contained and targets the local machine by default:

| Setting | Value | Effect |
|---|---|---|
| `inventory` | `inventory` | Localhost unless another inventory is passed with `-i` |
| `roles_path` | `roles` | Roles resolve from this repository |
| `host_key_checking` | `False` | First SSH connection to a fresh host succeeds; re-enable it if you provision untrusted hosts |
| `interpreter_python` | `auto_silent` | Finds the target's Python without extra warnings |
| `retry_files_enabled` | `False` | No `*.retry` files are left behind |

### Playbook variables

Defaults live in `group_vars/all.yml`; override them there or with `--extra-vars`.

| Variable | Default | Purpose |
|---|---|---|
| `packages_apt` | CLI baseline (git, curl, zip, `software-properties-common`, …) | APT packages installed by `base` |
| `packages_pip` | `[]` | Optional pip packages |
| `packages_snap` | `[]` | Optional snap packages |
| `docker_packages` | `docker.io`, `docker-compose-v2` | Docker packages |
| `docker_daemon` | `{}` | JSON written to `/etc/docker/daemon.json` |
| `arch` | `amd64` or `arm64` from facts | Release asset architecture |
| `topgrade_arch` | `x86_64` or `aarch64` from facts | Topgrade asset architecture |
| `kops_version` | `1.36.2` | kOps version |
| `kubectl_version` | `1.37.2` | kubectl version |
| `kubelogin_version` | `1.36.4` | kubelogin version |
| `istioctl_version` | `1.31.3` | istioctl version |
| `helm_version` | `4.3.1` | Helm version |
| `kustomize_version` | `5.8.3` | kustomize version |
| `topgrade_version` | `17.14.1` | Topgrade version |

### Role defaults

These are advanced knobs used by the helper roles. The defaults are usually correct.

| Variable | Default | Purpose |
|---|---|---|
| `custom_apt_arch` | `{{ arch }}` | Architecture segment in APT repository URLs |
| `custom_tools_lib_dir` | `/usr/local/lib` | Destination for extracted tool archives |
| `custom_tools_bin_dir` | `/usr/local/bin` | Destination for tool symlinks |
| `custom_tools_unarchive` | `false` | Force archive extraction instead of a single binary |
| `k8s_tools_github_url` | `https://github.com` | Base URL for GitHub-hosted releases |

Example override:

```bash
ansible-playbook ubuntu.yml --tags docker \
  --extra-vars '{"docker_daemon":{"log-driver":"local"}}'
```

## Project layout

```
ansible.cfg                  inventory path, roles path, defaults
inventory                    localhost by default; copy for remote hosts
requirements.yml             community.general collection
ubuntu.yml                   the playbook
bootstrap.sh                 installs Ansible and the collection
group_vars/all.yml           packages, versions, architecture
ci/verify-vm.sh              checks the tools inside the provisioned VM
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

The CI workflow runs on every push and pull request:

```bash
yamllint .
ansible-lint
ansible-playbook --syntax-check ubuntu.yml
```

For a real end-to-end run, use the disposable Vagrant VM. It is libvirt-only: the shared folder
uses 9p and the box is `alvistack/ubuntu-24.04`, pinned to `20260108.1.1` in the `Vagrantfile`.
The `cloud-image/ubuntu-24.04` box never receives a cloud-init datasource under libvirt, so it
boots without networking or SSH.

The same run is available as the **Vagrant** workflow. It is manual because nested
virtualization is slow and not always available on hosted runners. CI validates the playbook
statically; it does not provision a machine on every commit.

### Automated Vagrant test

Trigger **Actions → Vagrant → Run workflow**, or use the GitHub CLI:

```bash
gh workflow run vagrant-up.yml -f verify-idempotence=true
```

The job installs the libvirt host stack, checks KVM, runs `vagrant up`, executes
`ci/verify-vm.sh` inside the guest, optionally re-provisions and requires `changed=0`, uploads
the logs as the `vagrant-logs` artifact, and destroys the VM. It runs on `ubuntu-24.04` and
fails fast if `/dev/kvm` is missing. GitHub-hosted runners currently expose KVM, but nested
virtualization is not officially supported; use a self-hosted runner with KVM if you need a
guaranteed host. A run takes about 7-10 minutes.

`ci/verify-vm.sh` checks zsh/Oh My Zsh, Docker + Compose, every pinned Kubernetes tool, VS Code
and the base packages. The pinned versions are read from `group_vars/all.yml`, so bumping a
version there also updates the assertion.

## Vagrant VM (libvirt)

### 1. Host packages

Install Vagrant 2.3+ from <https://developer.hashicorp.com/vagrant/install>, then the libvirt
stack and the provider plugin. Package names vary by distribution:

```bash
# Debian/Ubuntu
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virtinst
vagrant plugin install vagrant-libvirt

# Arch
sudo pacman -S vagrant libvirt qemu-full virt-install
vagrant plugin install vagrant-libvirt
```

```bash
sudo systemctl enable --now libvirtd
```

KVM must be available (`ls /dev/kvm`).

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

```bash
vagrant up --provider=libvirt
```

The first run downloads the box, boots the VM, mounts the 9p share, installs Ansible in the
guest (from the official PPA) and runs `ubuntu.yml`. The guest uses the same playbook and
`group_vars` as a normal run. Allow a few GB of disk: the box is about 2 GB and the VM disk is
sparse. A successful run ends with:

```
PLAY RECAP
default : ok=45  changed=36  unreachable=0  failed=0  skipped=12
```

Re-running is safe and should report `changed=0`:

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
`ansible_local` runs.

### Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Waiting for domain to get an IP address...` for minutes | The host firewall is dropping DHCP or bridge traffic. Apply step 4, then check `virsh -c qemu:///system domifaddr ansible-DRP_default` and `journalctl -u libvirtd`. |
| `/vagrant` is empty or missing | 9p permission problem. Run `vagrant ssh -c 'dmesg --level=err,warn'` and verify step 3. |
| `vagrant status` hangs | Another `vagrant` process holds the machine lock. Wait for it, or stop it before retrying. |
| Ansible install fails in the guest | The guest has no egress. Re-check step 4 with `vagrant ssh -c 'curl -I https://archive.ubuntu.com'`. |
| Guest boots to a `login:` prompt but Vagrant cannot SSH | The box is missing its cloud-init datasource or the network never came up. Use the pinned `alvistack/ubuntu-24.04` box from the bundled `Vagrantfile`. |

### Validated environment

Validated end to end on 2026-10-31 with Vagrant 2.4.9, `vagrant-libvirt` 0.12.2, libvirt 12.8.0,
QEMU 11.1.3 and `alvistack/ubuntu-24.04` 20260108.1.1. The first `vagrant up` finished with
`failed=0`; a second `vagrant provision` finished with `changed=0`. The **Vagrant** workflow
repeated the same checks on an `ubuntu-24.04` GitHub-hosted runner in 7m17s.

## Notes and safety

- `ohmyzsh` manages `~/.zshrc`. The previous file is backed up next to it as
  `.zshrc.<timestamp>` on the first change.
- Adding the user to the `docker` group takes effect after a new login session.
- The playbook installs packages but does not upgrade the system or reboot it.
- The `docker` role restarts Docker only when `daemon.json` changes.
- Release versions are pinned deliberately. Bump the variables in `group_vars/all.yml`; the
  `custom_tools` role downloads the matching amd64/arm64 asset.
- The Vagrant box is pinned with `config.vm.box_version` for the same reason. To move to a newer
  box, update that line deliberately and re-run the end-to-end test before committing it.
- Test on a VM or a disposable host before running against a machine you care about.
- The Vagrant workflow changes the host, not just the VM: libvirt group membership, the QEMU
  user in `/etc/libvirt/qemu.conf`, optional socket authentication in `/etc/libvirt/libvirtd.conf`
  and the UFW rules for `virbr1`. Revert what you do not want to keep after testing.
- `vagrant destroy -f` removes the VM and its disk, but leaves the downloaded box in
  `~/.vagrant.d/boxes`. Remove it with `vagrant box remove alvistack/ubuntu-24.04` if you no
  longer need it.
- Vagrant replaces the box's insecure SSH key on first boot; `vagrant ssh` uses the generated
  key in `.vagrant/`.

## Inspired by

- <https://github.com/arcones/my-DRP>
- <https://pbassiner.github.io/blog/automating_my_dev_setup.html>
- <https://github.com/pbassiner/dev-env>
- <https://gist.github.com/komuw/b3b5d24977d4df7bd549#gistcomment-3741919>
- <https://github.com/Preetam/transverse/tree/master/.github/actions/ansible>

## License

[MIT](LICENSE)
