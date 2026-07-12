# Tutorial: the frontend design round trip

A complete dummy walkthrough of the catalog-first workflow: publish your component library
to Claude Design, design a feature from real components, approve it, and build it with the
`frontend:` commands. Every step shows the actual command typed and a realistic sample of
what comes back.

**The fictional workspace** (mirror of a real setup — substitute your own names):

```
~/work/education-platform/          ← workspace root, bootstrapped with agentic-workflow
  jam/education/                    ← Ruby backend repo (API + SPA pass-through)
    swagger.yaml                    ← OpenAPI spec for the API
  spa/                              ← Vue 3 + Vite repo: app code, component library, Storybook
```

Component library explorer running at `http://localhost:5600/component-library`.
The dummy feature: **course enrolments** — a list of a course's enrolments plus an
enrol-student form.

---

## Step 0 — Bootstrap and fill the project map

```bash
./agentic-workflow/bootstrap/install.sh ~/work/education-platform
```

Open the created `CLAUDE.md` and fill in the Project map:

| | |
|---|---|
| **SPA source** | `./spa/src` |
| **Backend repo** | `./jam/education` |
| **Component library (Storybook)** | `http://localhost:5600/component-library` |
| **Backend API spec** | `./jam/education/swagger.yaml` |
| **Claude Design project** | `Education Platform DS` |

Every `frontend:` command resolves this table first. Anything left `[TODO]` gets asked
about interactively — commands offer to write your answer back into the table.

## Step 1 — Publish the catalog

In Claude Code (this step is Claude-Code-only — it uses the DesignSync tool):

```
/frontend:design-sync
```

What happens: Claude builds Storybook statically, stages one self-contained preview page
per component variant with a card marker (`<!-- @dsCard group="Forms" -->`), diffs against
the design project, and presents an incremental plan before pushing:

```
Design project: Education Platform DS (design system, writable)
Plan — 34 new, 0 updated, 0 deleted:
  Buttons:     BaseButton (3 variants), IconButton
  Forms:       TextInput, SelectField, DatePicker, FormRow, …
  Tables:      DataTable (2 variants), PaginationBar
  Feedback:    AlertBanner, EmptyState, LoadingSpinner
  + CONVENTIONS.md (authoring rules for design sessions)
Push? (finalize_plan → write_files)
```

Approve it. Your library is now browsable at claude.ai/design, and `CONVENTIONS.md` tells
future design sessions to compose from these cards and reference components by story ID.

## Step 2 — Design the feature on claude.ai/design

In a Claude Design session against *Education Platform DS*, design the enrolments screen.
Because the catalog is there, the mockup composes real components — `DataTable` for the
list, `FormRow`/`SelectField`/`BaseButton` for the enrol form — and can be a clickable
interactive, not a static picture. Where nothing in the library fits, the design marks a
**new component** instead of silently inventing UI.

The session saves the design under `designs/enrolments/` with a manifest:

```json
{
  "feature": "enrolments",
  "uses": [
    "tables-datatable--standard",
    "forms-formrow--default",
    "forms-selectfield--searchable",
    "buttons-basebutton--primary",
    "feedback-emptystate--default"
  ],
  "new_components": [
    {
      "name": "EnrolmentStatusBadge",
      "purpose": "colour-coded enrolled/waitlisted/withdrawn status in the table",
      "closest_existing": "none — AlertBanner is block-level, this needs inline"
    }
  ],
  "status": "draft"
}
```

## Step 3 — Approve

A human reviews the mockup and flips one field: `"status": "approved"`. That's the whole
approval mechanism — cheap, explicit, and visible in the design project. Only approved
manifests are treated as implementation contracts.

## Step 4 — Ground the implementation

Back in Claude Code, in the workspace:

```
/frontend:discover     ← opens the discussion FROM the approved design
/frontend:analyze-patterns enrolments
```

`analyze-patterns` reads all four sources — approved design (intent), SPA disk (truth),
OpenAPI spec (contract), Storybook (catalog) — and writes
`plan/enrolments.patterns.md`. Excerpt:

```markdown
# Enrolments — patterns & components

## Design
- designs/enrolments/ in "Education Platform DS" — approved 2026-07-14

## Adopt these patterns
- List view + store: mirror courses module — `spa/src/modules/courses/views/CourseList.vue:18`
- Form + validation: mirror `spa/src/modules/courses/components/CourseForm.vue:31`

## Use these components
- DataTable (story: tables-datatable--standard) — enrolment list — props: columns, rows, loading
- SelectField (story: forms-selectfield--searchable) — student picker
- …

## Backend contract (./jam/education/swagger.yaml)
- listEnrolments  GET  /courses/{id}/enrolments — response: [EnrolmentSummary]
- createEnrolment POST /courses/{id}/enrolments — request: {studentId} response: Enrolment
- DRIFT: spec declares `status` enum [enrolled, waitlisted]; EnrolmentsController also
  returns `withdrawn` — confirm with the backend team which is right.

## Module decision
- Extend `spa/src/modules/courses/`? or new `spa/src/modules/enrolments/`? → operator chose
  NEW module (enrolment lifecycle is its own bounded context).

## Gaps to build
- EnrolmentStatusBadge (from the approved design) — inline status badge, none in library
```

Note the drift flag: spec-first doesn't mean spec-blind — code that disagrees with the
spec surfaces as a question, not a silent choice.

## Step 5 — Plan and decompose

```
/frontend:plan-feature enrolments
/frontend:decompose
```

The plan treats the approved design as acceptance criteria for the views and stacks story
branches in the SPA repo:

```
feat/enrolments                     ← plan base branch
  ├─ feat/enrolments/01-types-service   types + ACL over listEnrolments/createEnrolment
  ├─ feat/enrolments/02-store           Pinia store
  ├─ feat/enrolments/03-components      EnrolmentStatusBadge (→ library!), table + form composition
  ├─ feat/enrolments/04-views           routes + container views
  └─ feat/enrolments/05-polish          empty/error/loading, a11y pass
```

## Step 6 — Build and review

Per story: build → `/frontend:code-structure` → `/frontend:review-loop` (Vitest green is
the definition of done). Before the PR stack merges, `/enterprise-review` audits the
change against DDD/modularity/dependency/OO/security principles; the PR flow itself is the
`engineer:` commands (`/engineer:create-pr` → `/engineer:review-pr` → …).

## Step 7 — Close the loop

`EnrolmentStatusBadge` was built into the **component library** (not buried in the feature
module — it's a reusable primitive). After merge:

```
/frontend:design-sync
```

```
Plan — 1 new, 0 updated: Feedback: EnrolmentStatusBadge (3 variants)
```

The next design round starts with a richer catalog. That's the round trip.

---

## Cursor differences

- Commands are flat with a prefix: `/frontend-discover`, `/frontend-analyze-patterns`, …
- `/frontend-design-sync` and the design-manifest read are **Claude Code only** (they use
  the DesignSync tool). In Cursor, paste the manifest content when `analyze-patterns`
  asks, and run the sync itself from a Claude Code session.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `analyze-patterns` ignores the design | `status` is still `"draft"` — drafts are context, not contracts. Approve it. |
| Commands keep asking for locations | Project map rows missing or `[TODO]` — fill the table in `CLAUDE.md`. |
| Design cards render broken | Storybook static pages aren't self-contained — `design-sync` falls back to dedicated Vite preview pages; check its report of which route it took. |
| Push rejected / wrong project | Target must be a design-system project (type is immutable at creation) — `design-sync` verifies and offers to create one. |
| Spec vs code disagree | That's the drift flag working — resolve with the backend team; don't hand-pick a side silently. |
