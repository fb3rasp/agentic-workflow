#!/usr/bin/env bash
# sync.sh — generate harness-native packages from shared/ (the single source of truth).
#
#   ./build/sync.sh            # build dist/claude and dist/cursor
#   ./build/sync.sh --install  # also link into ~/.cursor and print Claude install steps
#
# Authoring rule: edit only shared/. Never edit dist/ (it is generated & gitignored).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED="$ROOT/shared"
DIST="$ROOT/dist"
CLAUDE="$DIST/claude"
CURSOR="$DIST/cursor"
PLUGIN_NAME="core-workflow"
VERSION="0.1.0"

rm -rf "$DIST"
mkdir -p "$CLAUDE/.claude-plugin" \
         "$CLAUDE/plugins/$PLUGIN_NAME/.claude-plugin" \
         "$CLAUDE/plugins/$PLUGIN_NAME/commands" \
         "$CLAUDE/plugins/$PLUGIN_NAME/agents" \
         "$CLAUDE/plugins/$PLUGIN_NAME/hooks" \
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

  # Claude
  {
    echo "---"
    [ "$kind" = "agent" ] && echo "name: $name"
    echo "description: $desc"
    echo "---"
    echo
    echo "$body"
  } > "$cdest"

  # Cursor
  {
    echo "---"
    [ "$kind" = "agent" ] && echo "name: $name"
    echo "description: $desc"
    echo "---"
    echo
    echo "$body"
  } > "$udest"
}

echo "==> commands"
for f in "$SHARED"/commands/*.md; do
  n="$(basename "$f")"
  emit_md "$f" "$CLAUDE/plugins/$PLUGIN_NAME/commands/$n" "$CURSOR/commands/$n" command
done

echo "==> agents"
for f in "$SHARED"/agents/*.md; do
  n="$(basename "$f")"
  emit_md "$f" "$CLAUDE/plugins/$PLUGIN_NAME/agents/$n" "$CURSOR/agents/$n" agent
done

echo "==> hooks (verbatim, executable in both)"
cp "$SHARED"/hooks/*.sh "$CLAUDE/plugins/$PLUGIN_NAME/hooks/"
cp "$SHARED"/hooks/*.sh "$CURSOR/hooks/"
chmod +x "$CLAUDE/plugins/$PLUGIN_NAME/hooks/"*.sh "$CURSOR/hooks/"*.sh

echo "==> mcp"
cp "$SHARED/mcp.json" "$CLAUDE/plugins/$PLUGIN_NAME/.mcp.json"
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

echo "==> hook wiring"
# Claude hook config (verify field names against your Claude Code version with /hooks)
cat > "$CLAUDE/plugins/$PLUGIN_NAME/hooks/hooks.json" <<'JSON'
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
cat > "$CLAUDE/.claude-plugin/marketplace.json" <<JSON
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
cat > "$CLAUDE/plugins/$PLUGIN_NAME/.claude-plugin/plugin.json" <<JSON
{ "name": "$PLUGIN_NAME", "version": "$VERSION", "description": "Agentic SDLC workflow commands, agents, and hooks." }
JSON
cat > "$CURSOR/.cursor-plugin/plugin.json" <<JSON
{ "name": "agentic-workflow", "version": "$VERSION", "description": "Agentic SDLC workflow commands, agents, hooks, and rules." }
JSON

echo "==> done. Built:"
echo "    $CLAUDE"
echo "    $CURSOR"

if [ "${1:-}" = "--install" ]; then
  echo "==> linking Cursor plugin into ~/.cursor/plugins/local"
  mkdir -p "$HOME/.cursor/plugins/local"
  rm -rf "$HOME/.cursor/plugins/local/agentic-workflow"
  ln -s "$CURSOR" "$HOME/.cursor/plugins/local/agentic-workflow"
  echo "    linked. Reload Cursor (Developer: Reload Window)."
  echo
  echo "==> Claude Code: add this marketplace, then install the plugin:"
  echo "    /plugin marketplace add $CLAUDE"
  echo "    /plugin install $PLUGIN_NAME@agentic-workflow"
fi
