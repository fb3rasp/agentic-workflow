---
description: Push branch, open GitHub PR, write plan/<slug>.pr-review.md — confirm first
---

Open a GitHub pull request for the current branch. **Do not review or score** — use
`/review-pr` or `/pr-review-loop` after the PR exists.

## Feature slug and state file

Infer the feature slug from the current branch: replace `/` with `-`
(e.g. `roster/02-api` → `roster-02-api`).

State file: `plan/<slug>.pr-review.md`

## GitHub tooling (gh-first)

Pre-flight: `gh auth status` — if not authenticated, stop with setup instructions.

| Action | Command |
|---|---|
| Current branch | `git branch --show-current` |
| Push | `git push -u origin HEAD` (if not already pushed) |
| Create PR | `gh pr create --title "…" --body "…" --base <base>` |
| View created PR | `gh pr view --json number,url,baseRefName,headRefName` |

Use GitHub MCP only if `gh` is unavailable or fails.

## Steps

1. **Gather context** — current branch, commits ahead of base, diff stat
   (`git diff --stat origin/<base>...HEAD`), test status (run the project test suite).

2. **Pre-flight checks**
   - Tests must be green before opening the PR.
   - Warn if diff exceeds ~1,000 lines (suggest stacked PR split per standards).
   - Confirm branch is pushed (push if operator approves).

3. **Confirm with operator** — present proposed PR title, body (use project PR template
   if `.github/pull_request_template.md` exists), and base branch (default: repo default
   branch). **Wait for approval** before creating.

4. **Create PR** — `gh pr create` with approved title, body, and base.

5. **Write state file** — create or overwrite `plan/<slug>.pr-review.md`:
   ```yaml
   feature: <slug>
   pr: <number>
   url: <github pr url>
   branch: <head branch>
   base: <base branch>
   iteration: 0
   last_overall: null
   last_dimensions: {}
   mode: confirm
   history: []
   ```

6. **Suggest next step** — run `/review-pr` for a scored review, or `/pr-review-loop`
   to enter the full fix-and-re-review cycle.

## Does not

- Score or review the diff.
- Post review comments.
- Enter the fix loop.
