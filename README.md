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

- Ubuntu 24.04, 64-bit (amd64 or arm64).
- A user with `sudo`. The playbook uses `become` for system changes.
- Network access to Ubuntu, Microsoft, GitHub and the Kubernetes release endpoints.
- Ansible 2.16 or newer on the machine running the playbook.

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

Defaults live in `group_vars/all.yml`; override them there or with `--extra-vars`.

| Variable | Default | Purpose |
|---|---|---|
| `packages_apt` | CLI baseline (git, curl, zip, `software-properties-common`, …) | APT packages installed by `base` |
| `packages_pip` | `[]` | Optional pip packages |
| `packages_snap` | `[]` | Optional snap packages |
| `docker_packages` | `docker.io`, `docker-compose-v2` | Docker packages |
| `docker_daemon` | `{}` | JSON written to `/etc/docker/daemon.json` |
| `arch` | `amd64` or `arm64` from facts | Release asset architecture |
| `kops_version` | `1.36.2` | kOps version |
| `kubectl_version` | `1.37.2` | kubectl version |
| `kubelogin_version` | `1.36.4` | kubelogin version |
| `istioctl_version` | `1.31.3` | istioctl version |
| `helm_version` | `4.3.1` | Helm version |
| `kustomize_version` | `5.8.3` | kustomize version |
| `topgrade_version` | `17.14.1` | Topgrade version |

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

For a real end-to-end run, use the disposable Vagrant VM (requires Vagrant, libvirt or
VirtualBox, and a few GB of disk):

```bash
vagrant up
vagrant destroy -f
```

The same run is available from the **Vagrant** workflow with `workflow_dispatch`. It is manual
because nested virtualization is slow and not always available on hosted runners. CI validates
the playbook statically; it does not provision a machine on every commit.

## Notes and safety

- `ohmyzsh` manages `~/.zshrc`. The previous file is backed up next to it as
  `.zshrc.<timestamp>` on the first change.
- Adding the user to the `docker` group takes effect after a new login session.
- The playbook installs packages but does not upgrade the system or reboot it.
- The `docker` role restarts Docker only when `daemon.json` changes.
- Release versions are pinned deliberately. Bump the variables in `group_vars/all.yml`; the
  `custom_tools` role downloads the matching amd64/arm64 asset.
- Test on a VM or a disposable host before running against a machine you care about.

## Inspired by

- <https://github.com/arcones/my-DRP>
- <https://pbassiner.github.io/blog/automating_my_dev_setup.html>
- <https://github.com/pbassiner/dev-env>
- <https://gist.github.com/komuw/b3b5d24977d4df7bd549#gistcomment-3741919>
- <https://github.com/Preetam/transverse/tree/master/.github/actions/ansible>

## License

[MIT](LICENSE)
