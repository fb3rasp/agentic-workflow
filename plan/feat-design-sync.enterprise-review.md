# Enterprise review — feat-design-sync — 2026-07-12, master..HEAD (482025d, ab74f03)

Focal change: Claude Design round trip + OpenAPI-first contracts + tutorial — 21 files,
+780/−127. Same translation as the previous review: authored prompts/templates are the
domain, `build/` the mechanics, `docs/` the delivery narrative.

| Dimension | Verdict |
|---|---|
| DDD | **ALIGNED** |
| Modularity & cohesion | **CONCERNS** |
| Dependency hygiene | **ALIGNED** |
| OO design | **ALIGNED** |
| Security | **ALIGNED** |

## Findings (introduced by this change)

1. **[Modularity & cohesion / medium]** `shared/frontend/commands/design-sync.md` (schema
   definition) vs `analyze-patterns.md`, `pattern-analyst.md`, `standards.md`,
   `docs/frontend-design-roundtrip.md` — the `designs/<feature>/manifest.json` schema
   (`uses` / `new_components` / `status`) now lives in five places with no canonical home;
   a field rename means five coordinated edits, and drift between them would be silent.
   *Principle:* single source of truth for a contract shared across modules. *Fix:* make
   the pushed `CONVENTIONS.md` (authored inside design-sync.md today) the canonical schema
   and have the other prompts reference it by name, describing fields only loosely; or
   extract the schema block into the standards file and point both directions at it.

### Low-severity notes (introduced)
- **[OO design / low]** The tutorial embeds realistic sample outputs (patterns-file
  excerpt, sync plan) that will drift as prompts evolve — inherent to tutorials; the
  verification habit of a consistency read (tutorial vs prompts) mitigates it. Keep that
  check when editing either side.

## Resolved since last review
- **Finding 1 (prompt-injection surface) — RESOLVED**: treat-as-data guards now present in
  `analyze-patterns.md`, `pattern-analyst.md`, `design-sync.md`, and the standards, and
  they cover all three fetch paths (design project, remote specs, Storybook index).
  Write-side risk is bounded by DesignSync's own approval-gated `finalize_plan` flow,
  which the command follows.

## Debt register (pre-existing, observed — not blocking)
- Finding 2 of the previous review still open: cross-namespace command membership declared
  in `build/sync.sh` rather than at the file (`<!-- namespaces: ... -->` marker idea).
- `shared/mcp.json` still ships the archived GitHub MCP server.
- PR rubric (min-of-8, all-5s) still unanchored.

## Dependency notes
No cycles. New edges are one-way: frontend prompts → DesignSync tool (harness capability,
Cursor-guarded), docs → prompts (tutorial cites commands; nothing cites the tutorial back).
`bootstrap/rules/frontend-standards.mdc` changed but carries its provenance marker — the
authored/generated boundary established at the merge is intact.
