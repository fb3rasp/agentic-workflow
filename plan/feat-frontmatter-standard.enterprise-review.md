# Enterprise review — feat-frontmatter-standard — 2026-07-19, master..HEAD (5d52787, 213c115)

Focal change: YAML frontmatter standard for the 29 authored files + sync.sh parser +
read-only tool allowlists — 94 files, mostly mechanical. Same translation as prior
reviews: authored prompts are the domain, `build/` the mechanics.

| Dimension | Verdict |
|---|---|
| DDD | **ALIGNED** |
| Modularity & cohesion | **ALIGNED** |
| Dependency hygiene | **ALIGNED** |
| OO design | **ALIGNED** |
| Security | **ALIGNED** |

## Findings (introduced by this change)

None at medium or above.

### Low-severity notes (introduced)
- **[OO design / low]** `build/sync.sh` `emit_md` — the Claude and Cursor emission blocks
  are near-duplicates differing only in field passthrough. Intentional divergence (the
  harnesses accept different fields); extract a helper only if a third harness appears.
- **[Modularity / low]** `fm_get` returns the first occurrence of a key; a duplicated key
  in authored frontmatter is silently ignored rather than flagged. Acceptable at current
  scale; add a duplicate-key check to `validate_fm` if it ever bites.

## Resolved since last reviews
- **feat-frontend-workflow finding 2 — RESOLVED**: cross-namespace membership is now
  declared at the file (`namespaces: engineer, frontend`) and `sync.sh` scans for it; the
  hardcoded filename list is gone.
- **Roadmap item "tool-restrict reviewer agents" — DONE**: six findings-only agents carry
  `tools:` allowlists in the Claude package (reviewer, pr-reviewer, enterprise-reviewer,
  frontend-reviewer: Read/Grep/Glob/Bash; pattern-analyst +WebFetch; researcher
  +WebFetch/WebSearch). Least-privilege improvement; the Bash caveat (shell can still
  write files) is documented honestly in the README rather than implied away.
- Long-standing defect fixed: trailing space on every generated `description:`.

## Debt register (pre-existing, observed — not blocking)
- feat-design-sync finding 1 still open: the design-manifest schema
  (`uses`/`new_components`/`status`) has no canonical home across its five citing files.
- `shared/mcp.json` still ships the archived GitHub MCP server.
- PR rubric (min-of-8, all-5s) still unanchored.

## Dependency notes
No cycles; no boundary changes. The authored→generated direction is strengthened: authored
files are now valid harness-native definitions themselves, and the generated packages are
pure per-harness projections of them (field filtering only). Validation moved from a
line-1 regex to a structured parse that fails naming the file.
