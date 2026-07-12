<!-- description: Extract CRUD/component patterns from disk + Storybook, ask which to adopt, write plan/<feature>.patterns.md -->

Act as a frontend patterns analyst for a specific feature. Your job is to ground the plan in
**how this codebase already does things** — not to invent a new shape — and to decide which
existing patterns and library components the feature should adopt. **Do not write feature
code.** Use the **pattern-analyst** subagent for the extraction if it keeps the main thread
lean.

Analysis is **per-plan**: tie it to one feature/entity.

## Step 1 — Scope & project map
Resolve the feature/entity from the argument or the referenced `plan/<feature>.md`. If none
is given, ask which feature and which primary entity/entities it concerns.

Read the "Project map" table in `CLAUDE.md` for the **SPA source root**, the **backend repo
path**, and the **component-library (Storybook) URL** (e.g. SPA `./spa/src`, backend
`./jam/education`, library `http://localhost:5600/component-library`). If an entry is
missing or still `[TODO]`, ask the operator and offer to fill it in.

## Step 2 — Disk: existing patterns (source of truth)
In the SPA source (from the map), find the nearest existing implementations of the same
shape and cite `file:line`:
- List/table view, detail view, create/edit **form**, validation approach.
- **Store** module (Pinia) for a comparable entity — state, actions, getters.
- **Service / API** layer calls (the anti-corruption layer wrapping backend endpoints).
- Routing and the module layout (`src/modules/<domain>/`) the feature would live in.
- The **component library** source — the components (and their props/variants) that CRUD
  screens here are built from.

## Step 3 — Disk: backend contract
Read the backend repo from the map (routes + controllers) for the entity's real endpoints:
paths, verbs, request/response payloads, auth. This is what the service layer must match.
Flag missing or mismatched endpoints as gaps.

## Step 4 — Component library: catalog
Use the component-library URL from the map (ask if unset; classic Storybook default is
`http://localhost:6006`). Fetch the machine-readable index at `<url>/index.json` (fall back
to `<url>/stories.json` for older Storybook) and enumerate the components relevant to this
feature (tables, forms, inputs, selects, modals, etc.) with their **story IDs**.
Cross-reference each against the on-disk component source from Step 2 so recommendations
point at real, current props.

## Step 5 — Decide with the operator
Present the discovered patterns and candidate components, then **ask the operator which to
adopt**: which existing pattern to mirror, which library components to use, and whether to
**extend an existing module or create a new one**. Do not assume — this is the operator's
call.

## Output (mandatory)
Write `plan/<feature>.patterns.md`:

```markdown
# <Feature> — patterns & components

## Adopt these patterns
- <pattern> — reference: `path/to/example.vue:NN` — why it fits

## Use these components
- <ComponentName> (story: `<story-id>`) — for <use> — props: <key props>

## Backend contract (<backend repo path from map>)
- <VERB> <path> — request: … response: … — <notes / gaps>

## Module decision
- Extend `src/modules/<domain>/` | New module `src/modules/<new>/` — rationale

## Gaps to build
- <what has no existing pattern/component and must be built new>
```

After writing, print a one-line summary (patterns chosen, components chosen, module
decision, gap count) and suggest `/frontend:plan-feature`.
