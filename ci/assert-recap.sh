#!/usr/bin/env bash
# Assert the PLAY RECAP counters in an Ansible log.
set -euo pipefail

log=${1:?usage: ci/assert-recap.sh LOG [EXPECTED_CHANGED]}
expected_changed=${2:-0}

[ -f "$log" ] || {
  printf 'no such log: %s\n' "$log" >&2
  exit 1
}

# Ansible colors the recap when the output is a terminal. Strip ANSI escapes so
# the same assertion works for local runs and captured CI logs.
recaps=$(sed -E $'s/\x1b\\[[0-9;]*[A-Za-z]//g' "$log" \
  | grep -E 'ok=[0-9]+ +changed=[0-9]+ +unreachable=[0-9]+ +failed=[0-9]+' || true)
[ -n "$recaps" ] || {
  printf 'no PLAY RECAP found in %s\n' "$log" >&2
  exit 1
}

status=0
while IFS= read -r recap; do
  changed=$(sed -n 's/.*changed=\([0-9][0-9]*\).*/\1/p' <<<"$recap")
  unreachable=$(sed -n 's/.*unreachable=\([0-9][0-9]*\).*/\1/p' <<<"$recap")
  failed=$(sed -n 's/.*failed=\([0-9][0-9]*\).*/\1/p' <<<"$recap")
  if [ "$changed" != "$expected_changed" ] || [ "$unreachable" != "0" ] || [ "$failed" != "0" ]; then
    printf 'unexpected recap: %s\n' "$recap" >&2
    status=1
  fi
done <<<"$recaps"

if [ "$status" -ne 0 ]; then
  printf 'expected changed=%s unreachable=0 failed=0\n' "$expected_changed" >&2
  exit 1
fi

printf 'recap ok: changed=%s unreachable=0 failed=0\n' "$expected_changed"
