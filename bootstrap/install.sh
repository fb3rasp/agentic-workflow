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
# .cursor/rules/standards.mdc, .github/pull_request_template.md, plan/.
# Symlinks (reference; hooks/MCP execute from plugin): .cursor/commands/,
# .cursor/agents/, .cursor/hooks/, .cursor/agentic-workflow-mcp.json,
# .cursor/agentic-workflow-plugin/.
#
# Plugin source resolution: $AGENTIC_WORKFLOW_PLUGIN → installed Cursor plugin →
# agentic-workflow clone's cursor/ dir. Exits non-zero if no plugin source is found.

set -euo pipefail

BOOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "usage: install.sh /path/to/repo" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "no such directory: $TARGET" >&2; exit 1; }

PLUGIN_FOUND=0
LINKS_CREATED=0

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
  [ -n "$root" ] && echo "$(cd "$root" && pwd)" || echo ""
}

# Subdir or env override pointing directly at a directory.
resolve_plugin_subdir() { # $1=commands|agents|hooks  $2=env-var for override (optional)
  local subdir="$1" env_var="${2:-}" override="" root=""
  if [ -n "$env_var" ]; then override="${!env_var:-}"; fi
  if [ -n "$override" ] && [ -d "$override" ]; then
    echo "$(cd "$override" && pwd)"; return
  fi
  root="$(resolve_plugin_root)"
  if [ -n "$root" ] && [ -d "$root/$subdir" ]; then
    echo "$(cd "$root/$subdir" && pwd)"; return
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

link_plugin_hooks() { # $1=target repo
  local target="$1" src name f
  src="$(resolve_plugin_subdir hooks AGENTIC_WORKFLOW_HOOKS)"
  if [ -z "$src" ]; then
    echo "  warn: plugin hooks not found — install plugin first (see README step 1)" >&2
    return 0
  fi
  mkdir -p "$target/.cursor/hooks"
  for f in "$src"/*.sh "$src"/hooks.json; do
    [ -f "$f" ] || continue
    link_safe "$f" "$target/.cursor/hooks/$(basename "$f")"
  done
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

echo "Bootstrapping $TARGET"
echo "==> plugin"
verify_plugin || PLUGIN_FOUND=0

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

echo "==> link (reference → plugin; hooks/MCP execute from plugin, not project)"
link_plugin_root "$TARGET"
link_plugin_md "$TARGET" commands AGENTIC_WORKFLOW_COMMANDS "commands"
link_plugin_md "$TARGET" agents   AGENTIC_WORKFLOW_AGENTS   "agents"
link_plugin_hooks "$TARGET"
link_plugin_mcp "$TARGET"

echo
if [ "$PLUGIN_FOUND" -eq 0 ]; then
  echo "FAILED: plugin not installed — symlinks skipped. Complete README step 1, then re-run:" >&2
  echo "  ./bootstrap/install.sh $TARGET" >&2
  exit 1
fi

echo "Done. Project links back to plugin at .cursor/agentic-workflow-plugin"
echo "Slash commands, agents, hooks, and MCP load from that plugin — reload Cursor/Claude if just installed."
