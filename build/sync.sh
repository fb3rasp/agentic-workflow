#!/usr/bin/env bash
# sync.sh — generate harness-native packages from shared/ (the single source of truth).
#
#   ./build/sync.sh            # regenerate the committed plugin packages
#   ./build/sync.sh --install  # also symlink the Cursor plugin + print Claude steps
#
# Output (TRACKED in git so the packages install from the GitHub remote):
#   .claude-plugin/marketplace.json     Claude marketplace catalog (must be at repo root)
#   plugins/core-workflow/              Claude plugin
#   cursor/                             Cursor plugin (symlink into ~/.cursor/plugins/local)
#
# Authoring rule: edit only shared/, then run this and commit the regenerated output.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED="$ROOT/shared"
PLUGIN_NAME="core-workflow"
VERSION="0.1.0"

CLAUDE_PLUGIN="$ROOT/plugins/$PLUGIN_NAME"   # Claude plugin dir
CURSOR="$ROOT/cursor"                         # Cursor plugin dir

# Clean only generated paths (never shared/ build/ bootstrap/).
rm -rf "$ROOT/.claude-plugin" "$ROOT/plugins" "$CURSOR"
mkdir -p "$ROOT/.claude-plugin" \
         "$CLAUDE_PLUGIN/.claude-plugin" \
         "$CLAUDE_PLUGIN/commands" "$CLAUDE_PLUGIN/commands/frontend" \
         "$CLAUDE_PLUGIN/agents" "$CLAUDE_PLUGIN/hooks" \
         "$CURSOR/.cursor-plugin" \
         "$CURSOR/commands" "$CURSOR/agents" "$CURSOR/hooks" "$CURSOR/rules"

# --- extract "<!-- description: ... -->" from line 1 of a shared md file ------
desc_of() { sed -n '1s/<!-- *description: *\(.*\) *-->/\1/p' "$1"; }
# --- body = everything after the marker line (and a leading blank line) -------
body_of() { tail -n +2 "$1" | sed '1{/^$/d;}'; }

emit_md() { # $1=src  $2=claude_dest  $3=cursor_dest  $4=kind(command|agent)
  local src="$1" cdest="$2" udest="$3" kind="$4"
  local name desc body
  name="$(basename "$src" .md)"
  desc="$(desc_of "$src")"
  body="$(body_of "$src")"
  for dest in "$cdest" "$udest"; do
    {
      echo "---"
      [ "$kind" = "agent" ] && echo "name: $name"
      echo "description: $desc"
      echo "---"
      echo
      echo "$body"
    } > "$dest"
  done
}

echo "==> commands"
for f in "$SHARED"/commands/*.md; do
  n="$(basename "$f")"
  emit_md "$f" "$CLAUDE_PLUGIN/commands/$n" "$CURSOR/commands/$n" command
done

echo "==> agents"
for f in "$SHARED"/agents/*.md; do
  n="$(basename "$f")"
  emit_md "$f" "$CLAUDE_PLUGIN/agents/$n" "$CURSOR/agents/$n" agent
done

# Frontend workflow: same plugin, own namespace. Claude Code namespaces by
# subdirectory (commands/frontend/discover.md -> /frontend:discover); Cursor's
# command model is flat, so the filename carries the prefix (/frontend-discover).
echo "==> frontend commands"
for f in "$SHARED"/frontend/commands/*.md; do
  n="$(basename "$f")"
  emit_md "$f" "$CLAUDE_PLUGIN/commands/frontend/$n" "$CURSOR/commands/frontend-$n" command
done

echo "==> frontend agents"
for f in "$SHARED"/frontend/agents/*.md; do
  n="$(basename "$f")"
  emit_md "$f" "$CLAUDE_PLUGIN/agents/$n" "$CURSOR/agents/$n" agent
done

echo "==> hooks (verbatim, executable in both)"
cp "$SHARED"/hooks/*.sh "$CLAUDE_PLUGIN/hooks/"
cp "$SHARED"/hooks/*.sh "$CURSOR/hooks/"
chmod +x "$CLAUDE_PLUGIN/hooks/"*.sh "$CURSOR/hooks/"*.sh

echo "==> mcp"
cp "$SHARED/mcp.json" "$CLAUDE_PLUGIN/.mcp.json"
cp "$SHARED/mcp.json" "$CURSOR/mcp.json"

echo "==> rule (standards) for Cursor + bootstrap"
RULE="$ROOT/bootstrap/rules/standards.mdc"
{
  echo "---"
  echo "description: Shared engineering standards (architecture, PRs, testing, security, context)"
  echo "alwaysApply: true"
  echo "---"
  echo
  cat "$SHARED/standards.md"
} > "$RULE"
cp "$RULE" "$CURSOR/rules/standards.mdc"

echo "==> rule (frontend standards) for Cursor + bootstrap"
# Not alwaysApply: attaches when frontend files are in play, so backend repos
# bootstrapped with the same scaffolding don't get Vue standards injected.
FRULE="$ROOT/bootstrap/rules/frontend-standards.mdc"
{
  echo "---"
  echo "description: Frontend engineering standards (Vue/Vite SPA, DDD modules, component-library-first, testing)"
  echo "globs: **/*.vue, **/*.ts, **/*.tsx, vite.config.*"
  echo "alwaysApply: false"
  echo "---"
  echo
  cat "$SHARED/frontend/standards.md"
} > "$FRULE"
cp "$FRULE" "$CURSOR/rules/frontend-standards.mdc"

echo "==> hook wiring"
# Claude hook config (verify field names against your Claude Code version with /hooks)
cat > "$CLAUDE_PLUGIN/hooks/hooks.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/dep-age-guard.sh" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/format-changed.sh" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/run-tests.sh" } ] }
    ]
  }
}
JSON
# Cursor hook config (Cursor's schema differs — verify in Cursor settings)
cat > "$CURSOR/hooks/hooks.json" <<'JSON'
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [ { "command": "./hooks/dep-age-guard.sh" } ],
    "afterFileEdit":        [ { "command": "./hooks/format-changed.sh" } ],
    "stop":                 [ { "command": "./hooks/run-tests.sh" } ]
  }
}
JSON

echo "==> manifests"
cat > "$ROOT/.claude-plugin/marketplace.json" <<JSON
{
  "name": "agentic-workflow",
  "owner": { "name": "$(git -C "$ROOT" config user.name 2>/dev/null || echo "you")" },
  "plugins": [
    {
      "name": "$PLUGIN_NAME",
      "source": "./plugins/$PLUGIN_NAME",
      "description": "Agentic SDLC workflow: discovery, planning, decomposition, review loop, architecture docs."
    }
  ]
}
JSON
cat > "$CLAUDE_PLUGIN/.claude-plugin/plugin.json" <<JSON
{ "name": "$PLUGIN_NAME", "version": "$VERSION", "description": "Agentic SDLC workflow commands, agents, and hooks." }
JSON
cat > "$CURSOR/.cursor-plugin/plugin.json" <<JSON
{ "name": "agentic-workflow", "version": "$VERSION", "description": "Agentic SDLC workflow commands, agents, hooks, and rules." }
JSON

echo "==> done. Generated (tracked):"
echo "    .claude-plugin/marketplace.json"
echo "    plugins/$PLUGIN_NAME/   (Claude)"
echo "    cursor/                 (Cursor)"

if [ "${1:-}" = "--install" ]; then
  echo "==> linking Cursor plugin into ~/.cursor/plugins/local"
  mkdir -p "$HOME/.cursor/plugins/local"
  rm -rf "$HOME/.cursor/plugins/local/agentic-workflow"
  ln -s "$CURSOR" "$HOME/.cursor/plugins/local/agentic-workflow"
  echo "    linked. Reload Cursor (Developer: Reload Window)."
  echo
  echo "==> Claude Code: add the marketplace (from GitHub once pushed), then install:"
  echo "    /plugin marketplace add fb3rasp/agentic-workflow"
  echo "    /plugin install $PLUGIN_NAME@agentic-workflow"
fi
