#!/usr/bin/env bash
# Installs the minimum tooling needed to run this repository's playbook.
# Safe to run more than once.
set -euo pipefail

cd "$(dirname "$0")"

minimum_ansible="2.16"

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "Installing Ansible from the Ubuntu repositories..."
    sudo apt-get update
    sudo apt-get install --assume-yes ansible git
fi

ansible_version=$(ansible --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)
if [ -z "$ansible_version" ] || \
    [ "$(printf '%s\n%s\n' "$minimum_ansible" "$ansible_version" | sort -V | head -n 1)" != "$minimum_ansible" ]; then
    echo "Ansible ${ansible_version:-unknown} is installed, but ${minimum_ansible}+ is required." >&2
    echo "Install a newer Ansible, for example: pipx install ansible-core" >&2
    exit 1
fi

echo "Installing Ansible collections..."
ansible-galaxy collection install --requirements-file requirements.yml

echo
echo "Ansible ${ansible_version} is ready."
echo "Next: ansible-playbook ubuntu.yml"
echo "Preview changes first with: ansible-playbook ubuntu.yml --check --diff"
