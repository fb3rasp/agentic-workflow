#!/usr/bin/env bash
# run-tests: run the project's test suite. Auto-detects the runner.
# Wired as a "stop"/end-of-turn hook so a change isn't declared done until green.
#
# Claude Code Stop-hook semantics: exit 2 blocks the stop and feeds stderr back to
# the agent; any other exit code is non-blocking. Claude sets stop_hook_active in
# the stdin JSON when the agent is already continuing because this hook blocked —
# exit 0 then, or the hook loops forever. Set RUN_TESTS_SKIP=1 to bypass.

set -uo pipefail

[ "${RUN_TESTS_SKIP:-0}" = "1" ] && exit 0

# Infinite-loop guard: don't re-block a stop this hook already blocked once.
if [ ! -t 0 ]; then
  STDIN="$(cat 2>/dev/null || true)"
  if [ -n "$STDIN" ]; then
    if command -v jq >/dev/null 2>&1; then
      [ "$(printf '%s' "$STDIN" | jq -r '.stop_hook_active // empty' 2>/dev/null)" = "true" ] && exit 0
    else
      case "$STDIN" in *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;; esac
    fi
  fi
fi

cd "${CLAUDE_PROJECT_DIR:-${CURSOR_PROJECT_DIR:-$PWD}}" || exit 0

run_suite() {
  if [ -f package.json ]; then
    if grep -q '"test"' package.json; then
      if   [ -f pnpm-lock.yaml ]; then pnpm test
      elif [ -f yarn.lock ];      then yarn test
      elif [ -f bun.lockb ];      then bun test
      else npm test --silent
      fi
      return $?
    fi
    echo "run-tests: no \"test\" script in package.json — skipping." >&2
    return 0
  fi

  if [ -f pyproject.toml ] || [ -f setup.cfg ] || [ -d tests ]; then
    if command -v pytest >/dev/null 2>&1; then pytest -q; return $?; fi
  fi

  echo "run-tests: no recognised test setup — skipping." >&2
  return 0
}

OUTPUT="$(run_suite 2>&1)"
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  {
    echo "run-tests: test suite FAILED (exit $STATUS) — fix the failures before finishing."
    printf '%s\n' "$OUTPUT" | tail -n 40
  } >&2
  exit 2
fi
exit 0
