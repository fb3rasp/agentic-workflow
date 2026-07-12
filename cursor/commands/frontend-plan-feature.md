---
description: Turn frontend discovery + patterns into a persisted risk-first plan under plan/ 
---

You are in FRONTEND PLANNING mode. **Do not write implementation code.** Use the
**frontend-planner** subagent if a roadmap in isolation keeps the main thread lean.

Using the discovery understanding and the `plan/<feature>.patterns.md` from
`/frontend:analyze-patterns` (if it exists — otherwise suggest running that first):

1. Confirm the goal and constraints.
2. Produce an architecture sketch for the SPA:
   - **Module layout** — which `src/modules/<domain>/` the work lives in; extend vs. new
     module (carry the decision from the patterns file).
   - **Components** — which library components to compose (with story IDs) and which new
     components must be built; container vs. presentational split.
   - **State** — Pinia store shape; server-derived vs. client-only state.
   - **Service / ACL layer** — the backend endpoints this wraps (by `operationId` and
     schema when the project map declares an OpenAPI spec; from routes/controllers
     otherwise) and the mapping to domain types.
   - **Design contract** — when an approved design exists (`designs/<feature>/` in the
     Claude Design project, via the patterns file), its screens and component usage are
     the acceptance criteria for the views; call out anywhere the plan deviates from it.
   - **Routes** and navigation changes.
3. Order the work **risk-first** — prove the riskiest/unknown parts first (new backend
   integration, auth, complex interactive components, streaming) before routine list/form
   screens and polish.
4. Break the work into phases with clear milestones and acceptance criteria (including which
   tests must pass). Name the **per-plan base branch** in `spa` (e.g. `feat/<feature>`).
5. Write the result to `plan/<feature>.md`: goal, architecture, phases, risk-first ordering,
   component/module decisions, and open decisions for the operator.

The plan file is the durable record — write it so a fresh agent session could pick up the
work from it alone. When done, suggest `/frontend:decompose` if the work is large.
