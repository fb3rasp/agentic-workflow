#!/usr/bin/env bash
# cursor-shell-guard: Cursor beforeShellExecution adapter for dep-age-guard.
#
# Cursor reads a JSON verdict from stdout: {"permission":"allow"|"deny", ...}.
# dep-age-guard blocks via exit code 2 (Claude Code semantics) with the reason
# on stderr. Cursor also treats a bare exit 2 as deny, but its docs don't say
# what happens to stderr then — so translate to an explicit deny verdict with
# the reason attached as user_message/agent_message.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Generated package layout has the guard next to this adapter; the authored
# layout (shared/hooks/cursor/) keeps it one level up.
GUARD="$DIR/dep-age-guard.sh"
[ -f "$GUARD" ] || GUARD="$DIR/../dep-age-guard.sh"
[ -f "$GUARD" ] || { printf '{"permission":"allow"}'; exit 0; }   # fail-open

STDIN=""
[ ! -t 0 ] && STDIN="$(cat 2>/dev/null || true)"

REASON="$(printf '%s' "$STDIN" | bash "$GUARD" 2>&1 >/dev/null)"
CODE=$?

if [ "$CODE" -eq 2 ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg msg "$REASON" \
      '{permission: "deny", user_message: $msg, agent_message: $msg}'
  else
    printf '{"permission":"deny","user_message":"Blocked by dep-age-guard: dependency younger than the minimum age.","agent_message":"Blocked by dep-age-guard: dependency younger than the minimum age."}'
  fi
else
  printf '{"permission":"allow"}'
fi
exit 0
