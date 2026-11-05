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
  local key=$1 value
  value=$(awk -v key="${key}:" '$1 == key { gsub(/"/, "", $2); print $2; exit }' "$GROUP_VARS")
  [ -n "$value" ] || fail "no ${key} in ${GROUP_VARS}"
  printf '%s' "$value"
}

expect_output() {
  local name=$1 expected=$2
  shift 2
  local output pattern
  output=$("$@" 2>&1 || true)
  pattern=${expected//./\\.}
  printf '%s\n' "$output" | grep -Eq "(^|[^0-9.])${pattern}([^0-9.]|$)" \
    || fail "$name: expected '${expected}', got: ${output}"
  pass "$name ${expected}"
}

command -v zsh >/dev/null 2>&1 || fail "zsh is missing"
[ "$(getent passwd "$(id -un)" | cut -d: -f7)" = "/bin/zsh" ] \
  || fail "zsh is not the login shell"
[ -d "$HOME/.oh-my-zsh" ] || fail "Oh My Zsh is missing"
for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search; do
  [ -d "$HOME/.oh-my-zsh/custom/plugins/$plugin" ] || fail "missing zsh plugin $plugin"
done

ohmyzsh_pin=$(expected_version ohmyzsh_version)
actual_ohmyzsh=$(git -C "$HOME/.oh-my-zsh" rev-parse HEAD 2>/dev/null || true)
[ "$actual_ohmyzsh" = "$ohmyzsh_pin" ] \
  || fail "Oh My Zsh is at ${actual_ohmyzsh:-an unknown commit}, expected $ohmyzsh_pin"
while read -r plugin version; do
  [ -n "$plugin" ] || continue
  actual_version=$(git -C "$HOME/.oh-my-zsh/custom/plugins/$plugin" describe --tags --exact-match 2>/dev/null || true)
  [ "$actual_version" = "$version" ] \
    || fail "$plugin is at ${actual_version:-an untagged commit}, expected $version"
done < <(awk '
  /^ohmyzsh_plugins:/ { in_list = 1; next }
  in_list && /^  - name:/ { name = $3; next }
  in_list && /^    version:/ { gsub(/"/, "", $2); print name, $2; next }
  in_list && /^[^[:space:]]/ { in_list = 0 }
' "$GROUP_VARS")
zsh_startup_errors=$(zsh -ic true 2>&1 >/dev/null)
[ -z "$zsh_startup_errors" ] || fail "zsh startup printed errors: ${zsh_startup_errors}"
[ "$(zsh -ic 'printf %s "$ZSH_THEME"' 2>/dev/null)" = "robbyrussell" ] \
  || fail "zsh does not load the managed .zshrc"
completion_dir="$HOME/.config/ansible-drp/completions.d"
[ -d "$completion_dir" ] || fail "completion directory is missing"
for tool in kops kubectl helm istioctl kubelogin; do
  [ -f "$completion_dir/$tool.zsh" ] || fail "completion for $tool is missing"
done
[ ! -e "$HOME/.config/ansible-drp/completions.zsh" ] || fail "legacy completion file is still present"
grep -q "completions.d" "$HOME/.zshrc" || fail ".zshrc does not source the completion directory"
completion_functions=$(zsh -ic 'whence -w _kubectl _helm _kops _istioctl _kubelogin' 2>/dev/null)
for function in _kubectl _helm _kops _istioctl _kubelogin; do
  printf '%s\n' "$completion_functions" | grep -Fxq "$function: function" \
    || fail "zsh completion $function is not loaded"
done
pass "zsh, Oh My Zsh, plugins and completions"

command -v docker >/dev/null 2>&1 || fail "docker is missing"
systemctl is-active --quiet docker || fail "docker service is not active"
docker info >/dev/null 2>&1 || fail "cannot use the Docker daemon as $(id -un)"
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
