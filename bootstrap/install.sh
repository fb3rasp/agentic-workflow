#!/usr/bin/env bash
# install.sh — drop repo-resident workflow scaffolding into a target project.
#
#   agentic-workflow/bootstrap/install.sh /path/to/my-repo
#
# Copies (without overwriting existing files): CLAUDE.md, .cursor/rules/standards.mdc,
# plan/, and a PR template. Run sync.sh first so standards.mdc is up to date.

set -euo pipefail

BOOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "usage: install.sh /path/to/repo" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "no such directory: $TARGET" >&2; exit 1; }

copy_safe() { # $1=src $2=dest
  if [ -e "$2" ]; then echo "  skip (exists): $2"; else
    mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "  added: $2"; fi
}

echo "Bootstrapping $TARGET"
copy_safe "$BOOT/CLAUDE.md.tmpl"           "$TARGET/CLAUDE.md"
copy_safe "$BOOT/rules/standards.mdc"      "$TARGET/.cursor/rules/standards.mdc"
copy_safe "$BOOT/pull_request_template.md" "$TARGET/.github/pull_request_template.md"
mkdir -p "$TARGET/plan"; [ -e "$TARGET/plan/.gitkeep" ] || touch "$TARGET/plan/.gitkeep"
echo "  ensured: $TARGET/plan/"

echo "Done. Then install the plugin in each harness (see repo README)."
