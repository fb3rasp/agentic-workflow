# Plan: PR review commands (`/create-pr`, `/review-pr`, `/pr-review-loop`)

**Status:** implemented  
**Last updated:** 2026-06-08

---

## Goal

Add three plugin slash commands that support a **GitHub PR quality loop** for bootstrapped
projects: open a PR, score it on eight dimensions (including security), fix issues on the
**same PR**, and re-review until **overall 5/5** or **five iterations** — with **operator
confirm at every command step and every loop iteration**.

Complements existing local `/review-loop` (correctness + tests, no GitHub) and
`/architecture-review` (docs drift, no scoring).

---

## Constraints (from discovery)

| Decision | Choice |
|---|---|
| Commands | Three: `/create-pr`, `/review-pr`, `/pr-review-loop` |
| Overall score | **Minimum** of all dimension scores |
| PR lifecycle | **Same PR** — push new commits to the branch; never open a new PR per iteration |
| Operator control | **Confirm** before create, before each review, before each fix/push, and each loop iteration |
| Iteration cap | 5 (safety rail even in confirm mode) |
| Security | Eighth review dimension — vulnerabilities are first-class |
| Harness | Author in `shared/`; `build/sync.sh`; update bootstrap templates + README |
| PR size | Single PR delivery |

### Resolved decisions

| Topic | Choice |
|---|---|
| State file | `plan/<feature>.pr-review.md` |
| Feature slug | Infer from branch: `/` → `-` (e.g. `roster/02-api` → `roster-02-api`) |
| GitHub tooling | **gh-first**; MCP fallback only |
| Review output | Post summary as **PR comment** via `gh pr comment` (after operator confirm) |
| Delivery | **Single PR** |

---

## Architecture sketch

```
┌─────────────────────────────────────────────────────────────────┐
│  Target project (bootstrapped)                                   │
│  plan/<feature>.pr-review.md  ← durable state (PR #, iteration) │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│  Plugin commands (shared/commands/)                              │
│  create-pr.md  │  review-pr.md  │  pr-review-loop.md             │
└───────┬────────┴────────┬───────┴──────────┬────────────────────┘
        │                 │                  │
        ▼                 ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────────────────┐
│ gh CLI       │  │ pr-reviewer  │  │ orchestrates review-pr logic │
│ GitHub MCP   │  │ subagent     │  │ fix → test → push → repeat   │
└──────────────┘  └──────────────┘  └──────────────────────────────┘
        │                 │
        └────────┬────────┘
                 ▼
        GitHub API (PR create, diff, push)
```

### Components touched

| Component | Change |
|---|---|
| `shared/commands/create-pr.md` | New — push, create PR, write state file, confirm |
| `shared/commands/review-pr.md` | New — fetch diff, 8-dimension score, findings only |
| `shared/commands/pr-review-loop.md` | New — iteration orchestrator |
| `shared/agents/pr-reviewer.md` | New — rubric-specialized, findings-only reviewer |
| `shared/commands/review-loop.md` | Optional cross-link in prompt (local vs PR scope) |
| `bootstrap/CLAUDE.md.tmpl` | Workflow diagram + command table + `@` includes |
| `README.md` | Command table, workflow branch, setup unchanged |
| `build/sync.sh` | No code change — picks up new `shared/` files automatically |

### Data flow

1. **`/create-pr`** — reads current branch → confirms with operator → `gh pr create` → writes `plan/<feature>.pr-review.md`.
2. **`/review-pr`** — reads state or `#N` arg → confirms → fetches diff → delegates to `pr-reviewer` → writes scores/findings to state → confirms next action.
3. **`/pr-review-loop`** — reads state → loop: review (same rubric) → confirm → fix → test → confirm → push → increment iteration → stop on 5/5, cap, or operator stop.

### Integration points

- **GitHub MCP** (`shared/mcp.json`) — fetch PR, diff, metadata.
- **`gh` CLI** — create PR, push, view diff (fallback if MCP unavailable).
- **`GITHUB_PERSONAL_ACCESS_TOKEN`** — required env var (document in MCP.md / command prompts).
- **Existing `reviewer` agent** — keep unchanged; `pr-reviewer` extends rubric for PR scoring.
- **Hooks** — `run-tests.sh` on stop still applies after fix phases.

---

## Scoring rubric (canonical — embed in `review-pr.md` + `pr-reviewer.md`)

**Overall = min(dimension scores).** Score 5 on a dimension only if no required changes
for that dimension. Score 5 overall only if **all eight dimensions are 5**.

| # | Dimension | Focus |
|---|---|---|
| 1 | Coding style | Naming, consistency, readability, project conventions |
| 2 | Extensibility | Extension points; open/closed; avoid brittle designs |
| 3 | Domain isolation | Bounded contexts; no cross-domain DB/API leaks |
| 4 | OO / structure | Service layer, SRP, sensible abstractions |
| 5 | Maintainability | Low coupling, clear ownership, safe to change |
| 6 | Redundancy | DRY; reuse existing services/modules |
| 7 | Testing | Coverage, edge cases, suite green |
| 8 | Security | Injection, authz/authn, secrets, crypto, SSRF, data exposure, unsafe deps |

**Security severity:** confirmed exploitable → dimension ≤ 1; suspected → ≤ 2 until resolved.

### Review output schema (mandatory in prompts)

```markdown
## PR #N — Iteration I — Overall: X/5 (min dimension)

| Dimension | Score |
|---|---|
| … | … |

**Limiting dimension(s):** …

### Blockers (must fix)
1. **[security]** `path:line` — problem. Fix: …

### Suggestions (optional for 5/5)
…

### Verdict
MERGE-READY | NOT MERGE-READY
```

---

## State file schema (`plan/<feature>.pr-review.md`)

```markdown
# PR review state
- feature: <slug>
- pr: <number>
- url: <github pr url>
- branch: <head branch>
- base: <base branch>
- iteration: <0–5>
- last_overall: <0–5|null>
- last_dimensions: { style: N, extensibility: N, …, security: N }
- mode: confirm
- history:
  - iteration: 1, overall: 3, limiting: [security, testing]
```

Operator fills `<feature>` slug from `CLAUDE.md` **Current work** or infers from branch.

---

## Phases (risk-first)

### Phase 1 — Review contract (highest risk: ambiguous rubric → useless loop)

**Prove:** `pr-reviewer` returns stable, parseable scores + blockers on a sample diff.

| Milestone | Deliverable | Acceptance |
|---|---|---|
| 1.1 | `shared/agents/pr-reviewer.md` | 8 dimensions, min rule, security checklist, findings-only |
| 1.2 | `shared/commands/review-pr.md` | Confirm gates, output schema, GitHub fetch instructions |
| 1.3 | Manual smoke test | Agent scores a real or fixture diff; overall = min(dims) |

**Risk:** Grade inflation → mitigate with explicit “5 = would approve with zero required changes”.

---

### Phase 2 — PR creation + state (GitHub integration risk)

**Prove:** Agent can open a PR and persist state for later commands.

| Milestone | Deliverable | Acceptance |
|---|---|---|
| 2.1 | `shared/commands/create-pr.md` | Confirm before create; writes state file; no review |
| 2.2 | State file template documented in command | Fresh session can read state and continue |
| 2.3 | Manual smoke test | `gh pr create` succeeds; state file correct |

**Risk:** Missing token / wrong repo → command must fail clearly with setup instructions.

---

### Phase 3 — Loop orchestrator (iteration + confirm + same-PR push)

**Prove:** Full cycle review → fix → test → push → re-review on same PR.

| Milestone | Deliverable | Acceptance |
|---|---|---|
| 3.1 | `shared/commands/pr-review-loop.md` | Confirm each iteration; cap at 5; same PR only |
| 3.2 | Cross-links to `/review-pr` rubric (DRY by reference) | No conflicting scoring rules |
| 3.3 | End-to-end smoke test | Score improves or operator stops; iteration logged in state |

**Risk:** Agent opens new PR instead of pushing → explicit “NEVER create a new PR in loop” in prompt.

---

### Phase 4 — Plugin packaging + docs

| Milestone | Deliverable | Acceptance |
|---|---|---|
| 4.1 | `./build/sync.sh` + commit generated `cursor/`, `plugins/` | Commands appear in both harnesses |
| 4.2 | `bootstrap/CLAUDE.md.tmpl` | Workflow branch + table + 3 `@` includes |
| 4.3 | `README.md` | Three commands in workflow diagram and command table |
| 4.4 | Optional: note in `shared/commands/review-loop.md` | When to use local vs PR review |

---

## Workflow placement (target)

```
build → /code-structure → /review-loop (local)
              ↓
        /create-pr          ← confirm
              ↓
        /review-pr          ← optional one-shot; confirm
              ↓
        /pr-review-loop     ← confirm each iteration; max 5; same PR
              ↓
           merge
```

---
