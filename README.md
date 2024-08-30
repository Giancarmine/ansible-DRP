# ansible-DRP - WIP! Don't use :fire:

An ansible collection, used to configure a ubuntu remotely or locally

[![vagrant-up](https://github.com/Giancarmine/ansible-DRP/actions/workflows/vagrant-up.yml/badge.svg)](https://github.com/Giancarmine/ansible-DRP/actions/workflows/vagrant-up.yml)

# Don't ask me anything, just do the magic.

```sh
wget -qO- https://github.com/Giancarmine/ansible-DRP/blob/main/bootstrap.sh | bash
```

## Prerequisites

### Install Ubuntu

- Get Ubuntu Latest LTS release ISO image from [ubuntu website](https://ubuntu.com/download/desktop)
- Create a bootable USB stick using ["rufus"](https://rufus.ie) or ["ventoy"](https://www.ventoy.net/en/index.html)
- During installation, ensure to **use full-disk-encryption**, which requires using LVM

### Setup Ansible

#### APT (preferred with ubuntu 22.04 LTS)

```sh
sudo apt update
sudo apt install ansible
NETRC=/dev/null ansible-galaxy collection install community.general
```

# Ansible Roles

| Role      | Include                                                                                                              | Pre-requisite | Status             |
| --------- | -------------------------------------------------------------------------------------------------------------------- | ------------- | ------------------ |
| base      | APT: wget, copyq, curl, fwupd, git, zip, unrar, unzip, net-tools, python3-pip, software-properties-common SNAP: NONE | NONE          | :white_check_mark: |
| ohmyzsh   | zsh and ohmyzsh config                                                                                               | NONE          | :white_check_mark: |
| vscode    | NONE                                                                                                                 | NONE          | :white_check_mark: |
| docker    | NONE                                                                                                                 | NONE          | :white_check_mark: |
| k8s_tools | kops, kubectl, kubelogin, istioctl, helm, kustomize                                                                  | NONE          | :white_check_mark: |

## Execute ansible tasks automatically (test purpose) :rocket:

### Execute ansible tasks automatically in a vagrant box

```bash
vagrant up
```

### Perform a vagrant clean-up

```bash
vagrant destroy
```

### Execute ansible tasks automatically in a vagrant box in a clean environment

```bash
vagrant destroy -f && vagrant up
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

## Tested on:

- ubuntu 22.04

---

## Inspired in

<https://github.com/arcones/my-DRP>

<https://pbassiner.github.io/blog/automating_my_dev_setup.html>

<https://github.com/pbassiner/dev-env>

<https://gist.github.com/komuw/b3b5d24977d4df7bd549#gistcomment-3741919>

<https://github.com/Preetam/transverse/tree/master/.github/actions/ansible>
