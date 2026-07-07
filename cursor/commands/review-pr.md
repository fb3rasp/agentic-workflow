---
description: Score a GitHub PR 0–5 (min of 8 dimensions), post review comment — findings only 
---

Review a GitHub pull request using the **pr-reviewer** rubric. **Do not edit code** in
this command — return scores and findings; fixing happens in `/pr-review-loop` or manually.

## Feature slug and state file

Infer the feature slug from the current branch: replace `/` with `-`
(e.g. `roster/02-api` → `roster-02-api`).

State file: `plan/<slug>.pr-review.md` — read/update after every review.

## GitHub tooling (gh-first)

Prefer the **`gh` CLI**. Use GitHub MCP only if `gh` is unavailable or fails.

Pre-flight: `gh auth status` — if not authenticated, stop with setup instructions.

| Action | Command |
|---|---|
| PR for current branch | `gh pr view --json number,url,baseRefName,headRefName,title` |
| Diff | `gh pr diff <N>` |
| Post comment | `gh pr comment <N> --body-file <file>` (use a temp file for long reviews) |

## Steps

1. **Resolve PR** — from `#N` argument, state file, or `gh pr view` on current branch.
   If none exists, stop and suggest `/create-pr`.

2. **Confirm with operator** — show PR number, URL, branch, base, and diff scope
   (full PR vs specific files if operator specifies). Wait for approval before fetching.

3. **Fetch diff** — `gh pr diff <N>`. If `gh` fails, try GitHub MCP as fallback.

4. **Review** — invoke the **pr-reviewer** subagent with the diff and project standards
   (`@.cursor/rules/standards.mdc`). Apply the rubric: 8 dimensions, overall = **min**
   of dimension scores (see `pr-reviewer` agent for output format).

5. **Update state file** — write scores, limiting dimensions, blockers, and append to
   `history`:
   ```yaml
   - iteration: <N>
     overall: <0-5>
     limiting: [dimension, ...]
   ```

6. **Confirm before posting** — show the full review summary to the operator. Wait for
   approval to post on GitHub.

7. **Post PR comment** — `gh pr comment <N> --body-file <file>` with the review summary.
   Record comment URL in state if available (`gh pr view <N> --comments`).

8. **Confirm next action** — ask operator: run `/pr-review-loop`, fix manually, or stop.

## Output

Report PR number, overall score, limiting dimensions, blocker count, whether comment was
posted, and suggested next step.
