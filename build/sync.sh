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
# Deterministic so regeneration is reproducible (CI drift check); forks override.
OWNER_NAME="${AGENTIC_WORKFLOW_OWNER:-Rainer Spittel}"

CLAUDE_PLUGIN="$ROOT/plugins/$PLUGIN_NAME"   # Claude plugin dir
CURSOR="$ROOT/cursor"                         # Cursor plugin dir

# Clean only generated paths (never shared/ build/ bootstrap/ — with one exception:
# bootstrap/rules/standards.mdc is regenerated below from shared/standards.md).
rm -rf "$ROOT/.claude-plugin" "$ROOT/plugins" "$CURSOR"
mkdir -p "$ROOT/.claude-plugin" \
         "$CLAUDE_PLUGIN/.claude-plugin" \
         "$CLAUDE_PLUGIN/commands" "$CLAUDE_PLUGIN/commands/frontend" \
         "$CLAUDE_PLUGIN/agents" "$CLAUDE_PLUGIN/hooks" \
         "$CURSOR/.cursor-plugin" \
         "$CURSOR/commands" "$CURSOR/agents" "$CURSOR/hooks" "$CURSOR/rules"

# --- frontmatter helpers ------------------------------------------------------
# Authored files start with a FLAT YAML frontmatter block (key: value scalars,
# comma-separated strings for lists — no nesting):
#   ---
#   description: <one line, required>
#   namespaces: engineer, frontend      # commands in shared/commands/ only
#   tools: Read, Grep, Glob, Bash       # agents; Claude package only
#   ---
fm_get() { # $1=file  $2=key — trimmed value, empty if absent
  awk -v key="$2" '
    NR==1 { if ($0=="---") { infm=1; next } else exit }
    infm && $0=="---" { exit }
    infm && index($0, key ":")==1 {
      v=substr($0, length(key)+2)
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      print v; exit
    }
  ' "$1"
}
fm_keys() { # keys present in the frontmatter block
  awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f&&/^[A-Za-z_-]+:/{sub(/:.*/,"");print}' "$1"
}
body_of() { # everything after the closing --- (one leading blank line stripped)
  awk '
    NR==1 && $0=="---" { infm=1; next }
    infm  && $0=="---" { infm=0; body=1; first=1; next }
    body { if (first && $0=="") { first=0; next }; first=0; print }
  ' "$1"
}
validate_fm() { # $1=file — line-1 "---" and a non-empty description, known keys only
  local f="$1" k
  if [ "$(sed -n '1p' "$f")" != "---" ] || [ -z "$(fm_get "$f" description)" ]; then
    echo "ERROR: missing/invalid frontmatter (need line-1 '---' and a description:) in $f" >&2
    exit 1
  fi
  for k in $(fm_keys "$f"); do
    case "$k" in
      description|namespaces|tools|model|argument-hint) ;;
      *) echo "warn: unknown frontmatter key '$k' in $f — ignored" >&2 ;;
    esac
  done
}

emit_md() { # $1=src  $2=claude_dest  $3=cursor_dest  $4=kind(command|agent)
  local src="$1" cdest="$2" udest="$3" kind="$4"
  local name desc body tools model arghint
  validate_fm "$src"
  name="$(basename "$src" .md)"
  desc="$(fm_get "$src" description)"
  tools="$(fm_get "$src" tools)"
  model="$(fm_get "$src" model)"
  arghint="$(fm_get "$src" argument-hint)"
  body="$(body_of "$src")"
  # Claude package — full field passthrough
  {
    echo "---"
    [ "$kind" = "agent" ] && echo "name: $name"
    echo "description: $desc"
    if [ "$kind" = "agent" ]; then
      [ -n "$tools" ] && echo "tools: $tools"
      [ -n "$model" ] && echo "model: $model"
    else
      [ -n "$arghint" ] && echo "argument-hint: $arghint"
    fi
    echo "---"
    echo
    echo "$body"
  } > "$cdest"
  # Cursor package — name/description only (Claude-specific fields dropped)
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
  emit_md "$f" "$CLAUDE_PLUGIN/commands/$n" "$CURSOR/commands/engineer-$n" command
done

echo "==> agents"
for f in "$SHARED"/agents/*.md; do
  n="$(basename "$f")"
  emit_md "$f" "$CLAUDE_PLUGIN/agents/$n" "$CURSOR/agents/$n" agent
done

# Frontend workflow: same plugin, own namespace. Claude Code namespaces by
# subdirectory (commands/frontend/discover.md -> /frontend:discover); Cursor's
# command model is flat, so the filename carries the prefix (/engineer-discover,
# /frontend-discover).
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

# Cross-namespace commands: declared at the file via "namespaces: engineer, frontend"
# (shared/commands/ default is engineer-only; the engineer emission happened above).
echo "==> cross-namespace commands (namespaces: ... frontend)"
for f in "$SHARED"/commands/*.md; do
  case ",$(fm_get "$f" namespaces | tr -d ' ')," in
    *,frontend,*)
      n="$(basename "$f")"
      emit_md "$f" "$CLAUDE_PLUGIN/commands/frontend/$n" "$CURSOR/commands/frontend-$n" command
      ;;
  esac
done

echo "==> hooks (shared verbatim in both; cursor/ adapters Cursor-only)"
cp "$SHARED"/hooks/*.sh "$CLAUDE_PLUGIN/hooks/"
cp "$SHARED"/hooks/*.sh "$CURSOR/hooks/"
cp "$SHARED"/hooks/cursor/*.sh "$CURSOR/hooks/"
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
  echo "<!-- GENERATED by agentic-workflow build/sync.sh from shared/standards.md — edit the source, not this file -->"
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
  echo "<!-- GENERATED by agentic-workflow build/sync.sh from shared/frontend/standards.md — edit the source, not this file -->"
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
# Cursor loads hooks only from enterprise/team/project/user hooks.json — never
# from plugins — so no hooks.json ships in the Cursor package. bootstrap/install.sh
# writes the project-level .cursor/hooks.json wiring instead.

echo "==> manifests"
cat > "$ROOT/.claude-plugin/marketplace.json" <<JSON
{
  "name": "agentic-workflow",
  "owner": { "name": "$OWNER_NAME" },
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
