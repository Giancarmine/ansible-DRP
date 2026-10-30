#!/usr/bin/env bash
# Installs the minimum tooling needed to run this repository's playbook.
# Safe to run more than once.
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "Installing Ansible from the Ubuntu repositories..."
    sudo apt-get update
    sudo apt-get install --assume-yes ansible git
fi

echo "Installing Ansible collections..."
ansible-galaxy collection install --requirements-file requirements.yml

echo
echo "Ansible $(ansible --version | head -n 1 | awk '{print $2}') is ready."
echo "Next: ansible-playbook ubuntu.yml"
echo "Preview changes first with: ansible-playbook ubuntu.yml --check --diff"
