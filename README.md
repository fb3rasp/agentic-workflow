# agentic-workflow

A reusable agentic software-development workflow, packaged for **both Claude Code and
Cursor** from a single source of truth.

You author once in `shared/`; `build/sync.sh` generates a native Claude Code plugin
marketplace and a native Cursor plugin. Per-project scaffolding (CLAUDE.md, AGENTS.md,
HOOKS.md, MCP.md, rules, plan folder, PR template, plus an **active** `.claude/` setup —
commands, agents, hooks, MCP — for Claude Code CLI) is dropped into each repo by
`bootstrap/install.sh`.

## The workflow

```
/discover  →  /plan-feature  →  /decompose  →  build  →  /code-structure  →  /review-loop
                                                        ↘ /document-architecture
                                                        ↘ /architecture-review
                                                        ↘ /create-pr → /review-pr → /pr-review-loop
                                                        ↘ /handoff (before clearing)
```

| Command | Phase | Does |
|---|---|---|
| `/discover` | Discovery | Back-and-forth to build shared understanding; refuses to code |
| `/plan-feature` | Plan | Writes a risk-first plan to `plan/<feature>.md` |
| `/decompose` | Plan | Splits a plan into stacked PRs (<1,000 lines each) |
| `/decompose-to-userstories` | Plan | Turns plan + stacked PRs into JIRA-ready EPICs and per-PR user stories in `plan/` |
| `/code-structure` | Build | Dedupe → service layer; enforces domain isolation |
| `/review-loop` | Review | review → fix → re-test until clean + green |
| `/enterprise-review` | Review | Deep principles audit: DDD, modularity & cohesion, dependency hygiene (no cycles), OO design, security — verdict per dimension, advisory; report to `plan/<slug>.enterprise-review.md` |
| `/review-ddd-architecture` | Any | Whole-codebase DDD/OO alignment review: assessment, target structure, phased plan in `plan/`, stacked-PR decomposition |
| `/create-pr` | Review | Open GitHub PR; write `plan/<slug>.pr-review.md` |
| `/review-pr` | Review | Score PR 0–5 (min of 8 dims); post PR comment |
| `/pr-review-loop` | Review | Confirm each iteration; fix, push, re-review until 5/5 or cap |
| `/document-architecture` | Any | C4 L1/L2/L3 + deployment, integrations, data flow, domains |
| `/architecture-review` | Review | Flags drift in a diff vs. `docs/architecture/` |
| `/handoff` | Any | Persists context to disk before clearing a heavy thread |

Subagents: `planner`, `researcher`, `reviewer`, `pr-reviewer`, `enterprise-reviewer`.
Hooks: `dep-age-guard` (block deps <14 days), `run-tests` (on stop), `format-changed` (on edit).

## The frontend workflow

A parallel command set for **Vue 3 + Vite SPA** repos (DDD modules, component-library-first,
Ruby backend in a separate repo). Locations are declared **per project** in a "Project map"
table in the bootstrapped `CLAUDE.md` — SPA source root, backend repo, component-library/
Storybook URL, **backend API spec** (OpenAPI/Swagger, path or URL — the contract is resolved
spec-first with routes/controllers as fallback and drift flagged), and the **Claude Design
project**. Claude Code: `/frontend:<name>`; Cursor: `/frontend-<name>`. Engineer
commands: Claude Code `/engineer:<name>`; Cursor: `/engineer-<name>`.

The workflow supports a **catalog-first design round trip**: `/frontend:design-sync`
publishes the component library to a claude.ai/design design-system project; mockups are
composed there from real components (new components get marked in a feature manifest); an
**approved** design then pre-seeds `/frontend:analyze-patterns` and acts as acceptance
criteria for the build. Full dummy walkthrough:
[docs/frontend-design-roundtrip.md](docs/frontend-design-roundtrip.md).

```
/frontend:discover → /frontend:analyze-patterns → /frontend:plan-feature
    → /frontend:decompose → build → /frontend:code-structure → /frontend:review-loop
```

| Command | Does |
|---|---|
| `/frontend:discover` | Views/routes, components, state, backend contract; refuses to code |
| `/frontend:analyze-patterns` | Extract CRUD/component patterns from disk + Storybook (`index.json`); ask the author which to adopt; write `plan/<feature>.patterns.md` |
| `/frontend:plan-feature` | Risk-first plan: module layout, components, store, service/ACL layer |
| `/frontend:decompose` | Split into stacked story branches (types → service → store → views) |
| `/frontend:code-structure` | Component split, composables, service layer, DDD module isolation |
| `/frontend:review-loop` | Review (reactivity, a11y, library-first, tests) → fix → re-test until green |
| `/frontend:enterprise-review` | Deep principles audit (shared with the engineer set) |
| `/frontend:review-ddd-architecture` | Whole-codebase DDD/OO alignment review (shared with the engineer set) |
| `/frontend:design-sync` | Publish the component catalog to the Claude Design project (incremental, approval-gated; Claude Code only) |

PR flow and handoff reuse the `engineer:` commands. Frontend subagents: `frontend-planner`,
`frontend-reviewer`, `pattern-analyst`. Standards rule: `frontend-standards.mdc`
(glob-scoped to frontend files, not `alwaysApply`).

## Not part of this repo

**Cursor skills** (`~/.cursor/skills-cursor/` — e.g. babysit, split-to-prs, sdk) are a
separate Cursor mechanism, not bundled with or referenced by agentic-workflow. Skills and
plugin slash **commands** are different systems; this setup has never included skill
symlinks or `@` includes. Use skills alongside the plugin if you want both — they are
independent.

## Layout

```
shared/                  # SOURCE OF TRUTH — author here only
  standards.md   commands/   agents/   hooks/   mcp.json
  frontend/              # frontend workflow: standards.md, commands/, agents/
build/
  sync.sh                # regenerates the committed packages from shared/
  test-hooks.sh          # hermetic behavioral tests for shared/hooks/ (also run in CI)
bootstrap/               # copied INTO each project repo
  CLAUDE.md.tmpl  AGENTS.md.tmpl  HOOKS.md.tmpl  MCP.md.tmpl  pull_request_template.md  plan/  install.sh
  rules/standards.mdc    # GENERATED from shared/standards.md by sync.sh
.github/workflows/ci.yml # drift check + shellcheck + hook tests

# --- generated by sync.sh, COMMITTED so it installs from the remote ---
.claude-plugin/          # Claude marketplace catalog (must be at repo root)
  marketplace.json
plugins/core-workflow/   # Claude plugin (commands, agents, hooks, .mcp.json)
cursor/                  # Cursor plugin (commands, agents, hooks, rules, mcp.json)
```

> The `.claude-plugin/`, `plugins/`, and `cursor/` trees are **generated** from
> `shared/` — never edit them directly. Edit `shared/`, run `sync.sh`, commit the result.

## Setup

Two steps: install the **plugin** once per machine (Cursor only — Claude Code needs no
plugin install for the bootstrap path), then **bootstrap** each project.

The harnesses differ in where things execute:
- **Claude Code:** bootstrap provisions a **native, active** `.claude/` setup —
  commands, agents, hooks (wired via `.claude/settings.json`), and a project-root
  `.mcp.json`. Everything runs from the project; no `/plugin install` required.
- **Cursor:** slash commands and MCP **execute from the installed plugin**; hooks run
  **from the project** — Cursor only loads hooks from a project/user/team/enterprise
  `hooks.json`, never from plugins, so bootstrap writes `.cursor/hooks.json` wiring the
  symlinked scripts in `.cursor/hooks/`.

### Step 1 — Install the plugin (once per machine)

**Cursor** (local symlink from a clone):
```bash
git clone …/agentic-workflow && cd agentic-workflow
./build/sync.sh --install     # → ~/.cursor/plugins/local/agentic-workflow
                              # then Developer: Reload Window
```
(Cursor team marketplaces need Teams/Enterprise; personal use is the local symlink path.)

**Claude Code** — nothing to install; bootstrap links defs from the clone's
`plugins/core-workflow/`. The marketplace route still works as an *alternative*:
```
/plugin marketplace add fb3rasp/agentic-workflow
/plugin install core-workflow@agentic-workflow
```
> Pick **one** Claude Code route per project — plugin *or* bootstrap `.claude/` links.
> Running both duplicates commands and fires every hook twice.

### Step 2 — Bootstrap each project

```bash
./agentic-workflow/bootstrap/install.sh /path/to/your-project
```

**Copied** (skip if file already exists):

| File | Purpose |
|---|---|
| `CLAUDE.md` | Project + workflow context |
| `AGENTS.md` | Subagent defs and usage |
| `HOOKS.md` | Hook schedule (reference) |
| `MCP.md` | MCP servers (reference) |
| `.claude/settings.json` | Claude Code hook wiring (**active**) |
| `.cursor/hooks.json` | Cursor hook wiring (**active**) |
| `.mcp.json` | Claude Code MCP servers (**active**) |
| `.cursor/rules/standards.mdc` | Engineering standards rule |
| `.github/pull_request_template.md` | PR template |
| `plan/` | Feature plans and handoffs |

**Symlinked** (re-run safe):

| Project path | Points to | Role |
|---|---|---|
| `.claude/commands/engineer/*.md` | Claude plugin slash-command prompts | **active** |
| `.claude/agents/*.md` | Claude plugin subagent prompts | **active** |
| `.claude/hooks/*.sh` | Claude plugin hook scripts | **active** |
| `.claude/agentic-workflow-plugin/` | Claude plugin root (link-back) | reference |
| `.cursor/agentic-workflow-plugin/` | Cursor plugin root — browse commands/agents here | reference |
| `.cursor/hooks/*.sh` | Cursor plugin hook scripts + adapters | **active** (wired by `.cursor/hooks.json`) |
| `.cursor/agentic-workflow-mcp.json` | Cursor plugin MCP config | reference |

In Claude Code the commands are **namespaced**: typing `/engineer` tab-completes the
whole group (`/engineer:discover`, `/engineer:plan-feature`, `/engineer:decompose`, …).
Override the namespace with `AGENTIC_WORKFLOW_NAMESPACE=<name>` when running
`install.sh` (re-running migrates old flat `.claude/commands/*.md` links into the
namespace dir). Cursor uses the same bounded-context idea with hyphen prefixes:
`/engineer-discover`, `/engineer-plan-feature`, `/frontend-plan-feature`, … — loaded
from the installed plugin only. Do **not** symlink into `.cursor/commands/`; that
registers duplicates. Re-run `install.sh` to prune stale flat symlinks.

`install.sh` **verifies** a plugin source exists and exits non-zero if none is found.
Cursor resolution: `AGENTIC_WORKFLOW_PLUGIN` → installed local plugin → clone's
`cursor/` dir; per-subdir overrides `AGENTIC_WORKFLOW_COMMANDS`, `AGENTIC_WORKFLOW_AGENTS`,
`AGENTIC_WORKFLOW_HOOKS`, `AGENTIC_WORKFLOW_MCP`. Claude Code resolution:
`AGENTIC_WORKFLOW_CLAUDE_PLUGIN` → clone's `plugins/core-workflow/` dir.

> The `.claude/` symlinks point into your local clone — keep the clone around (or set
> `AGENTIC_WORKFLOW_CLAUDE_PLUGIN`), and re-run `sync.sh` after editing `shared/` so
> linked projects pick up changes. If teammates don't share the clone path, gitignore
> the symlinked entries and have each machine run bootstrap.

After editing anything in `shared/`: re-run `./build/sync.sh` and **commit the
regenerated `.claude-plugin/`, `plugins/`, and `cursor/` output**.

## CI

Every push/PR runs `.github/workflows/ci.yml`:
- **Drift check** — regenerates from `shared/` and fails if the committed
  `.claude-plugin/`, `plugins/`, `cursor/`, or `bootstrap/rules/standards.mdc` differ
  (i.e. someone edited generated output by hand, or forgot to run `sync.sh`).
- **Shellcheck** — lints `shared/hooks/*.sh`, `build/*.sh`, `bootstrap/install.sh`.
- **Hook tests** — `./build/test-hooks.sh`, hermetic behavioral tests of the three
  hooks (fake `curl` serves canned registry responses; no network). Run it locally
  before committing hook changes — macOS covers the BSD `date` branch, CI the GNU one.

## Authoring conventions

- Each `commands/*.md` and `agents/*.md` begins with a **flat YAML frontmatter block** —
  the standard both harnesses define natively, so authored files are valid definitions in
  their own right:

  ```markdown
  ---
  description: <one line, required>
  namespaces: engineer, frontend    # optional, commands in shared/commands/ only —
                                    # adds emission into the frontend set
  tools: Read, Grep, Glob, Bash     # optional, agents only — Claude package tool allowlist
  model: <model>                    # optional, agents only — Claude package
  argument-hint: <hint>             # optional, commands only — Claude package
  ---
  ```

  Flat `key: value` scalars only (comma-separated strings for lists — Claude Code's own
  `tools:` format); no nesting. `sync.sh` validates (missing description fails the build,
  unknown keys warn) and maps fields per harness: the Claude package gets everything, the
  Cursor package gets `name`/`description` (Claude-specific fields are dropped). Agent
  `name` is always derived from the filename. The rest of the file is the prompt body,
  shared verbatim.
- The findings-only agents (`reviewer`, `pr-reviewer`, `enterprise-reviewer`,
  `frontend-reviewer`, `pattern-analyst`, `researcher`) carry read-only `tools:`
  allowlists, so "do not edit code" is structurally enforced in Claude Code, not just
  prose. Honest limitation: `Bash` stays on the list (diffs and `gh` need it), and shell
  can write files — this removes the Edit/Write **tools**, it is not a sandbox.
- Hook **logic** is plain `bash`, shared verbatim in both harnesses. The response
  protocols differ: Claude Code blocks via exit code 2; Cursor expects a JSON verdict
  on stdout (`permission`, `followup_message`). Thin adapters in `shared/hooks/cursor/`
  (`cursor-shell-guard.sh`, `cursor-stop-tests.sh`) translate — they ship only in the
  Cursor package. Wiring also differs: Claude Code via `.claude/settings.json`, Cursor
  via a project `.cursor/hooks.json` (both written by bootstrap; Cursor cannot load
  hooks from plugins).

## Verify (schemas evolve)

Plugin/hook manifest fields change across releases. After the first `sync.sh`, confirm:
- Claude Code: `/plugin` lists the marketplace & plugin; `/hooks` shows the three hooks.
- Cursor: the plugin appears under local plugins; in a bootstrapped project, hooks fire
  from `.cursor/hooks.json` (`beforeShellExecution` / `afterFileEdit` / `stop` — verify
  event names against Cursor's hook docs on major updates).

The dependency-age hook only blocks packages it can date via the npm registry; pip/others
pass through (extend `dep-age-guard.sh` to cover more registries).
