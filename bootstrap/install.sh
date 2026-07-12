#!/usr/bin/env bash
# install.sh — drop repo-resident workflow scaffolding into a target project.
#
#   agentic-workflow/bootstrap/install.sh /path/to/my-repo
#
# Two-step setup (see README):
#   1. Install the plugin in each harness (once per machine).
#   2. Run this script (once per project) — copies docs, symlinks plugin defs into
#      .cursor/ for browsing, and links .cursor/agentic-workflow-plugin → plugin root.
#
# Copies (without overwriting): CLAUDE.md, AGENTS.md, HOOKS.md, MCP.md,
# .cursor/rules/standards.mdc, .github/pull_request_template.md, plan/,
# .claude/settings.json (Claude hook wiring), .cursor/hooks.json (Cursor hook
# wiring — Cursor only loads hooks from project/user/team/enterprise hooks.json,
# never from plugins), .mcp.json (project-root MCP for Claude Code).
#
# Cursor symlinks: .cursor/hooks/ (ACTIVE — wired by .cursor/hooks.json),
# .cursor/commands/, .cursor/agents/ (reference; execute from plugin),
# .cursor/agentic-workflow-mcp.json, .cursor/agentic-workflow-plugin/.
#
# Claude Code symlinks (ACTIVE — Claude Code loads these natively, no plugin
# install needed): .claude/commands/<namespace>/ (default "engineer" →
# /engineer:discover etc.; override with AGENTIC_WORKFLOW_NAMESPACE),
# .claude/agents/, .claude/hooks/*.sh, .claude/agentic-workflow-plugin/.
#
# Cursor plugin source resolution: $AGENTIC_WORKFLOW_PLUGIN → installed Cursor
# plugin → clone's cursor/ dir. Claude plugin source resolution:
# $AGENTIC_WORKFLOW_CLAUDE_PLUGIN → clone's plugins/core-workflow/ dir.
# Exits non-zero if no plugin source is found.

set -euo pipefail

BOOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "usage: install.sh /path/to/repo" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "no such directory: $TARGET" >&2; exit 1; }

PLUGIN_FOUND=0
LINKS_CREATED=0

# Claude Code command namespace: .claude/commands/<ns>/discover.md → /<ns>:discover.
# Typing "/<ns>" in Claude Code tab-completes the whole command group.
CLAUDE_NS="${AGENTIC_WORKFLOW_NAMESPACE:-engineer}"

copy_safe() { # $1=src $2=dest
  if [ -e "$2" ]; then echo "  skip (exists): $2"; else
    mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "  added: $2"; fi
}

link_safe() { # $1=src $2=dest
  local src="$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "  ok (linked): $dest"
  elif [ -e "$dest" ]; then
    echo "  skip (exists): $dest"
  else
    ln -s "$src" "$dest"
    echo "  linked: $dest -> $src"
    LINKS_CREATED=$((LINKS_CREATED + 1))
  fi
}

# Plugin root: env override → ~/.cursor/plugins/local/agentic-workflow → clone cursor/
resolve_plugin_root() {
  local root=""
  if [ -n "${AGENTIC_WORKFLOW_PLUGIN:-}" ] && [ -d "$AGENTIC_WORKFLOW_PLUGIN" ]; then
    root="$AGENTIC_WORKFLOW_PLUGIN"
  elif [ -d "$HOME/.cursor/plugins/local/agentic-workflow" ]; then
    root="$HOME/.cursor/plugins/local/agentic-workflow"
  elif [ -f "$BOOT/../cursor/.cursor-plugin/plugin.json" ]; then
    root="$BOOT/../cursor"
  fi
  { [ -n "$root" ] && (cd "$root" && pwd); } || echo ""
}

# Claude plugin root: env override → clone's plugins/core-workflow.
# (The marketplace cache path is version-hashed and breaks on update — prefer the clone.)
resolve_claude_plugin_root() {
  local root=""
  if [ -n "${AGENTIC_WORKFLOW_CLAUDE_PLUGIN:-}" ] && [ -d "$AGENTIC_WORKFLOW_CLAUDE_PLUGIN" ]; then
    root="$AGENTIC_WORKFLOW_CLAUDE_PLUGIN"
  elif [ -f "$BOOT/../plugins/core-workflow/.claude-plugin/plugin.json" ]; then
    root="$BOOT/../plugins/core-workflow"
  fi
  { [ -n "$root" ] && (cd "$root" && pwd); } || echo ""
}

# Subdir or env override pointing directly at a directory.
resolve_plugin_subdir() { # $1=commands|agents|hooks  $2=env-var for override (optional)
  local subdir="$1" env_var="${2:-}" override="" root=""
  if [ -n "$env_var" ]; then override="${!env_var:-}"; fi
  if [ -n "$override" ] && [ -d "$override" ]; then
    (cd "$override" && pwd); return 0
  fi
  root="$(resolve_plugin_root)"
  if [ -n "$root" ] && [ -d "$root/$subdir" ]; then
    (cd "$root/$subdir" && pwd); return 0
  fi
  echo ""
}

resolve_plugin_file() { # $1=filename  $2=env-var for override (optional)
  local file="$1" env_var="${2:-}" override="" root=""
  if [ -n "$env_var" ]; then override="${!env_var:-}"; fi
  if [ -n "$override" ] && [ -f "$override" ]; then echo "$(cd "$(dirname "$override")" && pwd)/$(basename "$override")"; return; fi
  root="$(resolve_plugin_root)"
  if [ -n "$root" ] && [ -f "$root/$file" ]; then
    echo "$(cd "$root" && pwd)/$file"; return
  fi
  echo ""
}

verify_plugin() {
  local root
  root="$(resolve_plugin_root)"
  if [ -z "$root" ]; then
    echo "  ERROR: agentic-workflow plugin not found." >&2
    echo "  Install first (step 1), then re-run bootstrap:" >&2
    echo "    Cursor:  cd agentic-workflow && ./build/sync.sh --install" >&2
    echo "    Claude:  /plugin marketplace add fb3rasp/agentic-workflow" >&2
    echo "             /plugin install core-workflow@agentic-workflow" >&2
    echo "  Or set AGENTIC_WORKFLOW_PLUGIN=/path/to/cursor-plugin-dir" >&2
    return 1
  fi
  PLUGIN_FOUND=1
  echo "  plugin root: $root"
  case "$root" in
    "$HOME/.cursor/plugins/local/agentic-workflow") echo "  source: Cursor local plugin (active)" ;;
    *) echo "  source: agentic-workflow clone (fallback — run sync.sh --install for Cursor)" ;;
  esac
  return 0
}

link_plugin_root() { # $1=target repo
  local target="$1" root dest
  root="$(resolve_plugin_root)" || return 0
  [ -z "$root" ] && return 0
  mkdir -p "$target/.cursor"
  dest="$target/.cursor/agentic-workflow-plugin"
  link_safe "$root" "$dest"
}

link_plugin_md() { # $1=target  $2=commands|agents  $3=env-var  $4=label
  local target="$1" subdir="$2" env_var="$3" label="$4" src dest name
  src="$(resolve_plugin_subdir "$subdir" "$env_var")"
  if [ -z "$src" ]; then
    echo "  warn: plugin $label not found — install plugin first (see README step 1)" >&2
    return 0
  fi
  mkdir -p "$target/.cursor/$subdir"
  for f in "$src"/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    link_safe "$f" "$target/.cursor/$subdir/$name"
  done
}

link_plugin_hooks() { # $1=target repo — ACTIVE: wired by .cursor/hooks.json (written below)
  local target="$1" src f
  src="$(resolve_plugin_subdir hooks AGENTIC_WORKFLOW_HOOKS)"
  if [ -z "$src" ]; then
    echo "  warn: plugin hooks not found — install plugin first (see README step 1)" >&2
    return 0
  fi
  mkdir -p "$target/.cursor/hooks"
  # Cursor never loaded a hooks.json from this dir — prune the old dead symlink.
  if [ -L "$target/.cursor/hooks/hooks.json" ]; then
    rm "$target/.cursor/hooks/hooks.json"
    echo "  removed (dead config — wiring lives in .cursor/hooks.json): $target/.cursor/hooks/hooks.json"
  fi
  for f in "$src"/*.sh; do
    [ -f "$f" ] || continue
    link_safe "$f" "$target/.cursor/hooks/$(basename "$f")"
  done
}

write_cursor_hooks() { # $1=target repo — project-level Cursor hook wiring; never overwrites
  local target="$1" dest
  dest="$target/.cursor/hooks.json"
  if [ -e "$dest" ]; then
    echo "  skip (exists): $dest — merge the hooks wiring from HOOKS.md if not present"
    return 0
  fi
  mkdir -p "$target/.cursor"
  cat > "$dest" <<'JSON'
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      { "command": ".cursor/hooks/cursor-shell-guard.sh", "matcher": "npm|pnpm|yarn|bun|pip" }
    ],
    "afterFileEdit": [
      { "command": ".cursor/hooks/format-changed.sh" }
    ],
    "stop": [
      { "command": ".cursor/hooks/cursor-stop-tests.sh" }
    ]
  }
}
JSON
  echo "  added: $dest"
}

link_plugin_mcp() { # $1=target repo
  local target="$1" src
  src="$(resolve_plugin_file mcp.json AGENTIC_WORKFLOW_MCP)"
  if [ -z "$src" ]; then
    echo "  warn: plugin mcp.json not found — install plugin first (see README step 1)" >&2
    return 0
  fi
  mkdir -p "$target/.cursor"
  link_safe "$src" "$target/.cursor/agentic-workflow-mcp.json"
}

# --- Claude Code (native project-level defs under .claude/) -------------------

link_claude_root() { # $1=target repo
  local target="$1" root
  root="$(resolve_claude_plugin_root)"
  [ -z "$root" ] && return 0
  mkdir -p "$target/.claude"
  link_safe "$root" "$target/.claude/agentic-workflow-plugin"
}

link_claude_md() { # $1=target  $2=plugin subdir (commands|agents)  $3=dest subdir under .claude/
  local target="$1" subdir="$2" dest="$3" root f
  root="$(resolve_claude_plugin_root)"
  if [ -z "$root" ] || [ ! -d "$root/$subdir" ]; then
    echo "  warn: Claude plugin $subdir not found — skipping .claude/$dest" >&2
    return 0
  fi
  mkdir -p "$target/.claude/$dest"
  for f in "$root/$subdir"/*.md; do
    [ -f "$f" ] || continue
    link_safe "$f" "$target/.claude/$dest/$(basename "$f")"
  done
}

prune_flat_claude_commands() { # $1=target — remove pre-namespace flat command links
  local target="$1" root f
  root="$(resolve_claude_plugin_root)"
  [ -z "$root" ] && return 0
  for f in "$target/.claude/commands"/*.md; do
    [ -L "$f" ] || continue
    case "$(readlink "$f")" in
      "$root/commands/"*) rm "$f"; echo "  removed (moved to $CLAUDE_NS/): $f" ;;
    esac
  done
}

link_claude_hooks() { # $1=target repo — scripts only; wiring lives in .claude/settings.json
  local target="$1" root f
  root="$(resolve_claude_plugin_root)"
  if [ -z "$root" ] || [ ! -d "$root/hooks" ]; then
    echo "  warn: Claude plugin hooks not found — skipping .claude/hooks" >&2
    return 0
  fi
  mkdir -p "$target/.claude/hooks"
  for f in "$root/hooks"/*.sh; do
    [ -f "$f" ] || continue
    link_safe "$f" "$target/.claude/hooks/$(basename "$f")"
  done
}

write_claude_settings() { # $1=target repo — hook wiring; never overwrites
  local target="$1" dest
  dest="$target/.claude/settings.json"
  if [ -e "$dest" ]; then
    echo "  skip (exists): $dest — merge the hooks wiring from HOOKS.md if not present"
    return 0
  fi
  mkdir -p "$target/.claude"
  cat > "$dest" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/dep-age-guard.sh" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/format-changed.sh" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/run-tests.sh" } ] }
    ]
  }
}
JSON
  echo "  added: $dest"
}

copy_claude_mcp() { # $1=target repo — Claude Code reads .mcp.json at the project root
  local target="$1" root
  root="$(resolve_claude_plugin_root)"
  if [ -z "$root" ] || [ ! -f "$root/.mcp.json" ]; then
    echo "  warn: Claude plugin .mcp.json not found — skipping .mcp.json" >&2
    return 0
  fi
  copy_safe "$root/.mcp.json" "$target/.mcp.json"
}

verify_claude_plugin() {
  local root
  root="$(resolve_claude_plugin_root)"
  if [ -z "$root" ]; then
    echo "  ERROR: Claude plugin source not found." >&2
    echo "  Run from an agentic-workflow clone (plugins/core-workflow must exist —" >&2
    echo "  regenerate with ./build/sync.sh), or set" >&2
    echo "  AGENTIC_WORKFLOW_CLAUDE_PLUGIN=/path/to/plugins/core-workflow" >&2
    return 1
  fi
  echo "  claude plugin root: $root"
  return 0
}

echo "Bootstrapping $TARGET"
echo "==> plugin"
verify_plugin || PLUGIN_FOUND=0
CLAUDE_PLUGIN_FOUND=1
verify_claude_plugin || CLAUDE_PLUGIN_FOUND=0

echo "==> copy"
copy_safe "$BOOT/CLAUDE.md.tmpl"           "$TARGET/CLAUDE.md"
copy_safe "$BOOT/AGENTS.md.tmpl"           "$TARGET/AGENTS.md"
copy_safe "$BOOT/HOOKS.md.tmpl"            "$TARGET/HOOKS.md"
copy_safe "$BOOT/MCP.md.tmpl"              "$TARGET/MCP.md"
copy_safe "$BOOT/rules/standards.mdc"      "$TARGET/.cursor/rules/standards.mdc"
copy_safe "$BOOT/pull_request_template.md" "$TARGET/.github/pull_request_template.md"
mkdir -p "$TARGET/plan"
[ -e "$TARGET/plan/.gitkeep" ] || touch "$TARGET/plan/.gitkeep"
echo "  ensured: $TARGET/plan/"

echo "==> link Cursor (commands/agents/MCP from plugin; hooks ACTIVE via .cursor/hooks.json)"
link_plugin_root "$TARGET"
link_plugin_md "$TARGET" commands AGENTIC_WORKFLOW_COMMANDS "commands"
link_plugin_md "$TARGET" agents   AGENTIC_WORKFLOW_AGENTS   "agents"
link_plugin_hooks "$TARGET"
write_cursor_hooks "$TARGET"
link_plugin_mcp "$TARGET"

echo "==> link Claude Code (ACTIVE — loads natively from .claude/, no plugin install needed)"
link_claude_root "$TARGET"
prune_flat_claude_commands "$TARGET"
link_claude_md "$TARGET" commands "commands/$CLAUDE_NS"
link_claude_md "$TARGET" agents   agents
link_claude_hooks "$TARGET"
write_claude_settings "$TARGET"
copy_claude_mcp "$TARGET"

echo
if [ "$PLUGIN_FOUND" -eq 0 ] && [ "$CLAUDE_PLUGIN_FOUND" -eq 0 ]; then
  echo "FAILED: no plugin source found — symlinks skipped. Complete README step 1, then re-run:" >&2
  echo "  ./bootstrap/install.sh $TARGET" >&2
  exit 1
fi
[ "$PLUGIN_FOUND" -eq 0 ] && echo "warn: Cursor plugin missing — .cursor/ links skipped (see README step 1)." >&2
[ "$CLAUDE_PLUGIN_FOUND" -eq 0 ] && echo "warn: Claude plugin source missing — .claude/ links skipped." >&2

echo "Done."
echo "  Cursor:      commands/agents/MCP execute from the installed plugin; hooks run"
echo "               FROM THIS PROJECT — .cursor/hooks.json wires the .cursor/hooks/ links."
echo "  Claude Code: commands load from .claude/commands/$CLAUDE_NS/ — type /$CLAUDE_NS and"
echo "               tab to browse (/$CLAUDE_NS:discover, /$CLAUDE_NS:plan-feature, ...)."
echo "               Agents load from .claude/agents/, hooks run via .claude/settings.json,"
echo "               MCP from ./.mcp.json — no /plugin install required. Restart claude to pick up."
echo "  NOTE: if you ALSO installed core-workflow via /plugin install, uninstall it or skip"
echo "        the .claude/ links — otherwise commands and hooks run twice."
