---
description: Check a diff against docs/architecture and flag architectural drift
---

Review the current change (or referenced PR/diff) for **architectural drift** against the
documented architecture in `docs/architecture/`.

If `docs/architecture/` does not exist, say so and suggest running
`/document-architecture` first — do not invent the intended architecture.

Check the diff for:
1. **New or changed integrations** — any new external system, protocol, or auth path not
   in `integrations.md` (especially missing failure-mode handling).
2. **New/changed containers or data stores** not reflected in the L2 diagram.
3. **Domain-isolation violations** — cross-domain database access, reaching into another
   domain's internals, or new shared tables that bypass APIs/events (`domains.md`).
4. **Data-flow changes** — new flows, or changes to persistence/sync-vs-async not captured
   in the data-flow narrative.
5. **Service-layer erosion** — domain logic added to controllers/handlers/UI instead of
   the service layer.

For each finding give: severity, location (`file:line`), what drifted, and one of:
- **Update the docs** (the change is intentional — name the file/diagram to update), or
- **Fix the code** (the change violates the intended architecture).

End with a verdict: `ALIGNED`, `DOCS NEED UPDATE`, or `ARCHITECTURE VIOLATION`. Do not edit
files unless the operator asks — return findings.
