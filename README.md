# ansible-DRP - WIP! Don't use :fire:

An ansible playbooks collection, used to configure a ubuntu remotely or locally

# Don't ask me anything, just do the magic.

```sh
wget -qO- https://github.com/Giancarmine/ansible-DRP/blob/main/bootstrap.sh | bash
```

## Prerequisites

### Install Ubuntu

- Get Ubuntu Latest LTS release ISO image from [ubuntu website](https://ubuntu.com/download/desktop)
- Create a bootable USB stick using ["rufus"](https://rufus.ie) or ["ventoy"](https://www.ventoy.net/en/index.html)
- During install, ensure to __use full-disk-encryption__, which requires using LVM

### Setup Ansible

#### APT (preferred with ubuntu 22.04 LTS)

```sh
sudo apt update
sudo apt install ansible
NETRC=/dev/null ansible-galaxy collection install community.general
```

# Ansible Roles

### base

- install apt, snap and pip packages

# Execute ansible tasks automatically (test purpose) :rocket:

```bash
vagrant up
```

## Execute ansible tasks manually :wrench:

### Before Start

```bash
sh bootstrap.sh
```

### Execute

```bash
ansible-playbook utils.yml -K
```

## Tested in:
- ubuntu 22.04

---

## Inspired in

<https://github.com/arcones/my-DRP>

<https://pbassiner.github.io/blog/automating_my_dev_setup.html>

<https://github.com/pbassiner/dev-env>

<https://gist.github.com/komuw/b3b5d24977d4df7bd549#gistcomment-3741919>

<https://github.com/Preetam/transverse/tree/master/.github/actions/ansible>
