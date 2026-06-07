#!/usr/bin/env bash
# format-changed: best-effort auto-format of the file just edited.
# Wired as a PostToolUse hook on edit/write tools. Reads the file path from
# JSON stdin (.tool_input.file_path), $1, or $TOOL_FILE_PATH. Never fails the turn.

set -uo pipefail

FILE=""
if [ ! -t 0 ]; then
  STDIN="$(cat 2>/dev/null || true)"
  if [ -n "$STDIN" ] && command -v jq >/dev/null 2>&1; then
    FILE="$(printf '%s' "$STDIN" | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null)"
  fi
fi
[ -z "$FILE" ] && FILE="${1:-${TOOL_FILE_PATH:-}}"
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 0

if command -v prettier >/dev/null 2>&1; then
  case "$FILE" in
    *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.md|*.svelte|*.html|*.yaml|*.yml)
      prettier --write "$FILE" >/dev/null 2>&1 || true ;;
  esac
fi
exit 0
