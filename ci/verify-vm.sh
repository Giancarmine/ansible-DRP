#!/usr/bin/env bash
# Verifies the tools installed by ubuntu.yml inside the Vagrant VM.
set -euo pipefail

GROUP_VARS=/vagrant/group_vars/all.yml

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'ok: %s\n' "$*"
}

expected_version() {
  awk -F'"' -v key="^$1:" '$0 ~ key {print $2; exit}' "$GROUP_VARS"
}

expect_output() {
  local name=$1
  local expected=$2
  shift 2
  local output
  output=$("$@" 2>&1 || true)
  printf '%s\n' "$output" | grep -q -- "$expected" \
    || fail "$name: expected '$expected', got: $output"
  pass "$name $expected"
}

command -v zsh >/dev/null 2>&1 || fail "zsh is missing"
[ "$(getent passwd "$(id -un)" | cut -d: -f7)" = "/bin/zsh" ] \
  || fail "zsh is not the login shell"
[ -d "$HOME/.oh-my-zsh" ] || fail "Oh My Zsh is missing"
for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search; do
  [ -d "$HOME/.oh-my-zsh/custom/plugins/$plugin" ] || fail "missing zsh plugin $plugin"
done
pass "zsh, Oh My Zsh and plugins"

command -v docker >/dev/null 2>&1 || fail "docker is missing"
systemctl is-active --quiet docker || fail "docker service is not active"
docker compose version >/dev/null 2>&1 || fail "docker compose is missing"
id -nG | tr ' ' '\n' | grep -qx docker || fail "user is not in the docker group"
pass "docker and compose"

expect_output kubectl "$(expected_version kubectl_version)" kubectl version --client
expect_output helm "$(expected_version helm_version)" helm version
expect_output kops "$(expected_version kops_version)" kops version
expect_output istioctl "$(expected_version istioctl_version)" istioctl version --remote=false
expect_output kubelogin "$(expected_version kubelogin_version)" kubelogin --version
expect_output kustomize "$(expected_version kustomize_version)" kustomize version
expect_output topgrade "$(expected_version topgrade_version)" topgrade --version

command -v code >/dev/null 2>&1 || fail "VS Code is missing"
code --version >/dev/null 2>&1 || fail "VS Code does not run"
pass "VS Code"

command -v git >/dev/null 2>&1 || fail "git is missing"
command -v curl >/dev/null 2>&1 || fail "curl is missing"
pass "base packages"

printf '\nAll checks passed.\n'
