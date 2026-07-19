---
description: Enterprise architecture review — DDD, modularity, dependency hygiene, OO design, security; verdict per dimension
namespaces: engineer, frontend
---

Run a deep, principles-based review of the current change (or referenced PR / diff / path).
This is the enterprise complement to the other reviews: `/review-loop` checks correctness,
`/review-pr` scores for merge, `/architecture-review` checks drift against *documented*
architecture — this command audits against **reference principles**, regardless of what the
project has documented. **Advisory: it gates nothing.** Fixes flow to `/code-structure` or
`/review-loop`; merge gating stays with `/pr-review-loop`.

Invoke the **enterprise-reviewer** subagent for the analysis. Works for backend and
frontend repos alike (in a frontend repo, resolve the `CLAUDE.md` project map first so
module paths are right).

## Scope

1. **Focal change** — the working diff, a named PR (`gh pr diff <N>`), or a given path.
2. **Widen to affected modules** — for every module/domain the change touches, map its
   import/dependency graph. Cycles and direction violations are invisible in a raw diff.
   Prefer project tooling when configured (`dependency-cruiser`/`madge` for JS/TS,
   `packwerk` for Rails, `import-linter` for Python); otherwise trace imports manually
   from the touched files outward.
3. **Split findings** — **Introduced** (new or worsened by this change — actionable) vs.
   **Pre-existing** (debt observed nearby — recorded for the debt register, never treated
   as a blocker for this change).

## Dimensions (verdict each: ALIGNED | CONCERNS | VIOLATION)

1. **Domain-Driven Design** — domain logic lives in the domain/service layer (not
   controllers/handlers/UI); aggregate and entity boundaries respected; value objects for
   concepts without identity; ubiquitous language in names; anti-corruption layers at
   integration points; bounded-context integrity.
2. **Modularity & cohesion** — code that changes together resides together
   (package-by-feature, not scattered across layer-by-type folders); each module exposes an
   explicit public API; no deep reach-ins to another module's internals; frontend: no
   cross-module store/composable reach.
3. **Dependency hygiene** — dependencies point in the allowed direction (toward the domain
   / stable abstractions); **no circular dependencies** at module or file level; no layer
   skips (e.g. UI → repository directly); external systems behind adapters.
4. **OO design** — SOLID, encapsulation, composition over inheritance; patterns used where
   they pay for themselves — flag **over-engineering** (needless indirection, pattern for
   its own sake) as readily as under-design.
5. **Security** — the `pr-reviewer` checklist: injection, broken authn/authz, secrets
   exposure, weak crypto/session handling, SSRF/deserialization, data exposure.

Verdict rules per dimension: any high-severity **introduced** finding → `VIOLATION`;
medium-severity introduced findings → `CONCERNS`; otherwise `ALIGNED` (pre-existing debt
alone never drops a verdict below ALIGNED — it goes in the debt register instead).

## Output (mandatory)

Infer the feature slug from the current branch (replace `/` with `-`). Write the report to
`plan/<slug>.enterprise-review.md`:

```markdown
# Enterprise review — <slug> — <date, focal ref>

| Dimension | Verdict |
|---|---|
| DDD | … |
| Modularity & cohesion | … |
| Dependency hygiene | … |
| OO design | … |
| Security | … |

## Findings (introduced by this change)
1. **[dimension / severity]** `file:line` — problem. *Principle:* <the named principle
   violated>. *Fix:* concrete remediation.

## Debt register (pre-existing, observed — not blocking)
- `file:line` — observation. *Principle:* …

## Dependency notes
<cycles found/absent, direction violations, graph tooling used>
```

Then report a one-line summary (verdicts + introduced-finding count) and suggest next
steps: `/code-structure` or `/review-loop` for fixes; `/pr-review-loop` for the merge gate.
Do not edit code in this command.
