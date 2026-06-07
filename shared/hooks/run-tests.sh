#!/usr/bin/env bash
# run-tests: run the project's test suite. Auto-detects the runner.
# Wired as a "stop"/end-of-turn hook so a change isn't declared done until green.

set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-${CURSOR_PROJECT_DIR:-$PWD}}" || exit 0

if [ -f package.json ]; then
  if grep -q '"test"' package.json; then
    if   [ -f pnpm-lock.yaml ]; then pnpm test; exit $?
    elif [ -f yarn.lock ];      then yarn test; exit $?
    elif [ -f bun.lockb ];      then bun test;  exit $?
    else npm test --silent; exit $?
    fi
  fi
  echo "run-tests: no \"test\" script in package.json — skipping." >&2
  exit 0
fi

if [ -f pyproject.toml ] || [ -f setup.cfg ] || ls tests/ >/dev/null 2>&1; then
  command -v pytest >/dev/null 2>&1 && { pytest -q; exit $?; }
fi

echo "run-tests: no recognised test setup — skipping." >&2
exit 0
