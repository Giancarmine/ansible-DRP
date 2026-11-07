#!/usr/bin/env bash
# Creates a local virtualenv with the pinned Ansible controller and installs
# the required collection. Safe to run more than once.
set -euo pipefail

cd "$(dirname "$0")"

minimum_python="3.12"
venv=".venv"
requirements="requirements.txt"

python_supported() {
    local python=$1
    "$python" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 12) else 1)'
}

python_version() {
    "$1" -c 'import sys; print(".".join(str(part) for part in sys.version_info[:3]))'
}

if [ -x "$venv/bin/python" ]; then
    if ! python_supported "$venv/bin/python"; then
        echo "$venv was created with Python $(python_version "$venv/bin/python")." >&2
        echo "Python ${minimum_python}+ is required by the pinned Ansible controller." >&2
        echo "Remove it and re-run: rm -rf $venv" >&2
        exit 1
    fi
else
    python_bin=${PYTHON:-python3}
    if ! command -v "$python_bin" >/dev/null 2>&1; then
        echo "Python ${minimum_python}+ is required, but ${python_bin} was not found." >&2
        exit 1
    fi
    if ! python_supported "$python_bin"; then
        echo "Python ${minimum_python}+ is required by the pinned Ansible controller." >&2
        echo "Found Python $(python_version "$python_bin") at $(command -v "$python_bin")." >&2
        echo "Ubuntu 22.04 ships Python 3.10; use a newer controller host or install Python ${minimum_python}+." >&2
        exit 1
    fi
    if ! "$python_bin" -m venv "$venv"; then
        echo "Could not create $venv with Python $(python_version "$python_bin")." >&2
        echo "Install the venv package for Python ${minimum_python} and retry." >&2
        exit 1
    fi
fi

# shellcheck disable=SC1091
. "$venv/bin/activate"

python -m pip install --upgrade pip
pip install --requirement "$requirements"

required_ansible=$(sed -n 's/^ansible-core==//p' "$requirements" | head -n 1)
minimum_ansible=${required_ansible:-2.18.0}
ansible_version=$(ansible --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)
if [ -z "$ansible_version" ] || \
    [ "$(printf '%s\n%s\n' "$minimum_ansible" "$ansible_version" | sort -V | head -n 1)" != "$minimum_ansible" ]; then
    echo "Ansible ${ansible_version:-unknown} is installed, but ${minimum_ansible}+ is required." >&2
    exit 1
fi

collections_path="$PWD/.ansible/collections"
echo "Installing Ansible collections into ${collections_path}..."
# --force also replaces an already installed collection that has another
# version, so the pin in requirements.yml is always the one in use. The local
# path keeps this repository from modifying a shared Ansible installation.
ansible-galaxy collection install --force \
    --collections-path "$collections_path" \
    --requirements-file requirements.yml

echo
echo "Ansible ${ansible_version} is ready in ${venv}."
echo "Activate it with: source ${venv}/bin/activate"
echo "Then: ansible-playbook ubuntu.yml"
echo "Preview changes first with: ansible-playbook ubuntu.yml --check --diff"
