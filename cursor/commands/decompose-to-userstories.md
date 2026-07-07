---
description: Turn a decomposed plan into JIRA-ready EPICs and per-PR user stories under plan/ 
---

Act as an **Agile Product Owner**. You are given raw product discovery material: the
feature plan in `plan/<feature>.md`, its "Stacked PRs" decomposition (from
`/decompose`), and any brainstorming notes, transcripts, or technical details the
operator references. **Do not write implementation code.**

If no plan or decomposition is referenced, ask which `plan/` file to use. If the plan
has no "Stacked PRs" section, suggest running `/decompose` first.

## Step 1 — EPICs

Create **one or more EPICs** that capture the entire initiative. Prefer one EPIC per
coherent outcome; split only when the initiative clearly serves distinct goals. For
each EPIC state: `EPIC-N`, a title, a one-paragraph narrative (the why and the value),
and which PRs fall under it.

## Step 2 — User stories

Break the requirements into individual user stories. **Every PR in the decomposition
must be covered by at least one story**; a PR may yield several stories if it serves
distinct user needs. Purely technical PRs (scaffolding, CI) become enabler stories
written from the developer/operator perspective.

For each story provide:

- **User story** in the standard format: *As a… I want to… So that…*
- **Story points** estimate (Fibonacci: 1, 2, 3, 5, 8, 13) with a one-line rationale
- **EPIC reference** (`EPIC-N`)
- **Acceptance criteria** in Given–When–Then format (cover the PR's own acceptance
  criteria; add more where the plan implies them)
- **Edge cases** we should consider (draw from the plan's risks and review findings)
- **Related PR** it implements (`PR-N`, with the PR title from the decomposition)

## Output (mandatory)

Write the result to `plan/<feature>.userstories.md` — a new file, JIRA-ready for
copy-paste:

```markdown
# <Feature> — EPICs & user stories

Source: plan/<feature>.md (+ notes/transcripts used)

## EPIC-1: <title>
<narrative — the why and the value>
**Covers:** PR-1, PR-2, …

---

### US-1.1: <story title>
**Story:** As a <role>, I want <capability>, so that <benefit>.
**Points:** <n> — <rationale>
**EPIC:** EPIC-1
**Implements:** PR-1 — <PR title>

**Acceptance criteria**
- Given <context>, When <action>, Then <outcome>
- …

**Edge cases**
- …
```

Number stories `US-<epic>.<n>`. After writing, print a one-line summary table
(story ID → points → PR) so the operator can sanity-check coverage and totals before
creating the JIRA issues.
