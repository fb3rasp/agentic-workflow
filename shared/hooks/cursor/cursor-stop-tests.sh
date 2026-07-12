#!/usr/bin/env bash
# cursor-stop-tests: Cursor "stop" adapter for run-tests.
#
# Cursor's stop hook cannot block, but {"followup_message": "..."} auto-submits
# a message so the agent keeps iterating — capped by the hook's loop_limit
# (Cursor default 5). Only fires when the turn completed normally; never fights
# an operator abort. RUN_TESTS_SKIP=1 passes through to the underlying runner.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Generated package layout has the runner next to this adapter; the authored
# layout (shared/hooks/cursor/) keeps it one level up.
RUNNER="$DIR/run-tests.sh"
[ -f "$RUNNER" ] || RUNNER="$DIR/../run-tests.sh"
[ -f "$RUNNER" ] || { printf '{}'; exit 0; }

STDIN=""
[ ! -t 0 ] && STDIN="$(cat 2>/dev/null || true)"

STATUS="completed"
if [ -n "$STDIN" ] && command -v jq >/dev/null 2>&1; then
  STATUS="$(printf '%s' "$STDIN" | jq -r '.status // "completed"' 2>/dev/null)"
fi
if [ "$STATUS" != "completed" ]; then
  printf '{}'
  exit 0
fi

OUTPUT="$(bash "$RUNNER" </dev/null 2>&1)"
CODE=$?

if [ "$CODE" -ne 0 ]; then
  MSG="The test suite is failing — fix the failures before finishing:
$(printf '%s\n' "$OUTPUT" | tail -n 40)"
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg msg "$MSG" '{followup_message: $msg}'
  else
    printf '{"followup_message":"The test suite is failing — run it and fix the failures before finishing."}'
  fi
else
  printf '{}'
fi
exit 0
