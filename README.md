# agentic-workflow

A reusable agentic software-development workflow, packaged for **both Claude Code and
Cursor** from a single source of truth.

You author once in `shared/`; `build/sync.sh` generates a native Claude Code plugin
marketplace and a native Cursor plugin. Per-project scaffolding (CLAUDE.md, rules, plan
folder, PR template) is dropped into each repo by `bootstrap/install.sh`.

## The workflow

```
/discover  →  /plan-feature  →  /decompose  →  build  →  /code-structure  →  /review-loop
                                                        \-> /document-architecture
                                                        \-> /handoff (before clearing)
```

| Command | Phase | Does |
|---|---|---|
| `/discover` | Discovery | Back-and-forth to build shared understanding; refuses to code |
| `/plan-feature` | Plan | Writes a risk-first plan to `plan/<feature>.md` |
| `/decompose` | Plan | Splits a plan into stacked PRs (<1,000 lines each) |
| `/code-structure` | Build | Dedupe → service layer; enforces domain isolation |
| `/review-loop` | Review | review → fix → re-test until clean + green |
| `/document-architecture` | Any | C4 L1/L2/L3 + deployment, integrations, data flow, domains |
| `/architecture-review` | Review | Flags drift in a diff vs. `docs/architecture/` |
| `/handoff` | Any | Persists context to disk before clearing a heavy thread |

Subagents: `planner`, `researcher`, `reviewer`.
Hooks: `dep-age-guard` (block deps <14 days), `run-tests` (on stop), `format-changed` (on edit).

## Layout

```
shared/      # SOURCE OF TRUTH — author here only
  standards.md   commands/   agents/   hooks/   mcp.json
build/
  sync.sh        # generates dist/ for both harnesses
  frontmatter/
dist/        # GENERATED (gitignored) — dist/claude, dist/cursor
bootstrap/   # copied INTO each project repo
  CLAUDE.md.tmpl  rules/standards.mdc  pull_request_template.md  plan/  install.sh
```

## Setup

```bash
# 1. Build the packages (and link them into both harnesses)
./build/sync.sh --install

# 2. Claude Code: add the marketplace + install the plugin (printed by --install)
#    /plugin marketplace add  <repo>/dist/claude
#    /plugin install core-workflow@agentic-workflow

# 3. Cursor: --install symlinked dist/cursor into ~/.cursor/plugins/local;
#    reload Cursor (Developer: Reload Window).

# 4. Per project: scaffold the repo-resident files
./bootstrap/install.sh /path/to/your-project
```

Re-run `./build/sync.sh` after editing anything in `shared/`.

## Authoring conventions

- Each `commands/*.md` and `agents/*.md` begins with a single marker line:
  `<!-- description: ... -->`. `sync.sh` turns that into per-harness frontmatter; the
  rest of the file is the prompt body, shared verbatim.
- Hooks are plain `bash` and run identically in both harnesses. Only the **wiring**
  (`hooks.json`) differs per harness — that's the one place schemas diverge.

## Verify (schemas evolve)

Plugin/hook manifest fields change across releases. After the first `sync.sh`, confirm:
- Claude Code: `/plugin` lists the marketplace & plugin; `/hooks` shows the three hooks.
- Cursor: the plugin appears under local plugins; hooks fire (check Cursor's hook docs
  for the current `hooks.json` schema — `beforeShellExecution` / `afterFileEdit` / `stop`).

The dependency-age hook only blocks packages it can date via the npm registry; pip/others
pass through (extend `dep-age-guard.sh` to cover more registries).
