#!/usr/bin/env bash
# Run the static checks used by CI. Install requirements-dev.txt and the
# community.general collection first (bootstrap.sh does the latter).
set -euo pipefail

cd "$(dirname "$0")/.."

# Prefer the project virtualenv when it exists.
if [ -d .venv ] && [ -x .venv/bin/ansible-playbook ]; then
  PATH="$PWD/.venv/bin:$PATH"
  export PATH
fi

# Vagrant ships an embedded Ruby; use it when the host has no Ruby package.
if ! command -v ruby >/dev/null 2>&1 && [ -x /opt/vagrant/embedded/bin/ruby ]; then
  PATH="/opt/vagrant/embedded/bin:$PATH"
  export PATH
fi

python_bin=${PYTHON:-}
if [ -z "$python_bin" ]; then
  if command -v python >/dev/null 2>&1; then
    python_bin=python
  else
    python_bin=python3
  fi
fi

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

run ruby ci/verify-ubuntu-versions.rb
run "$python_bin" -m py_compile \
  ci/verify-checksums.py ci/check-box-updates.py ci/http_utils.py
run yamllint .
run ansible-lint
run ansible-playbook --syntax-check ubuntu.yml
run ruby -c Vagrantfile

# Exercise both forms of the deprecated Vagrant inventory flag.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@"
EOF
chmod +x "$tmp/ansible-playbook"

output=$(PATH="$tmp:$PATH" ci/ansible-playbook-compat \
  --inventory-file=/tmp/inventory --limit=ubuntu playbook.yml)
printf '%s\n' "$output"
grep -Fxq -- '--inventory=/tmp/inventory' <<<"$output"
grep -Fxq -- '--limit=ubuntu' <<<"$output"
grep -Fxq -- 'playbook.yml' <<<"$output"

output=$(PATH="$tmp:$PATH" ci/ansible-playbook-compat \
  --inventory-file /tmp/inventory playbook.yml)
printf '%s\n' "$output"
grep -Fxq -- '--inventory' <<<"$output"
grep -Fxq -- '/tmp/inventory' <<<"$output"

if [ "${SKIP_CHECKSUMS:-0}" = "1" ]; then
  printf '\n==> skipping release checksum verification (SKIP_CHECKSUMS=1)\n'
else
  run "$python_bin" ci/verify-checksums.py
fi

if [ -n "${ACTIONLINT:-}" ]; then
  run "$ACTIONLINT"
elif command -v actionlint >/dev/null 2>&1; then
  run actionlint
else
  printf '\n==> skipping actionlint (not installed)\n'
fi

shellcheck_bin=${SHELLCHECK:-}
if [ -z "$shellcheck_bin" ] && command -v shellcheck >/dev/null 2>&1; then
  shellcheck_bin=$(command -v shellcheck)
fi
if [ -n "$shellcheck_bin" ]; then
  run "$shellcheck_bin" \
    bootstrap.sh \
    ci/ansible-playbook-compat \
    ci/assert-recap.sh \
    ci/check.sh \
    ci/verify-vm.sh \
    roles/k8s_tools/files/usr/local/bin/kustomize-wrapper
else
  printf '\n==> skipping shellcheck (not installed)\n'
fi

if command -v zizmor >/dev/null 2>&1; then
  run zizmor .github/workflows
else
  printf '\n==> skipping zizmor (not installed)\n'
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  run git diff --check
fi

printf '\nAll checks passed.\n'
