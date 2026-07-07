---
description: Confirm each iteration — review, fix, push same PR, re-review until 5/5 or cap 5 
---

Run a **review → fix → test → push → re-review** loop on an existing GitHub PR until
**overall 5/5** or **five iterations**. Uses the same rubric as `/review-pr` (via
**pr-reviewer**). **Always confirm with the operator** before fixing, pushing, and each
new iteration.

**NEVER create a new PR in this loop** — only push commits to the existing PR branch.

## Feature slug and state file

Infer the feature slug from the current branch: replace `/` with `-`
(e.g. `roster/02-api` → `roster-02-api`).

State file: `plan/<slug>.pr-review.md` — must exist (run `/create-pr` first if missing).

## GitHub tooling (gh-first)

Same as `/review-pr`: prefer `gh` CLI; MCP fallback only.

| Action | Command |
|---|---|
| Diff | `gh pr diff <N>` |
| Post comment | `gh pr comment <N> --body-file <file>` |
| Push | `git push` (same branch — never `gh pr create`) |

## Loop (max 5 iterations)

For each iteration (starting at `state.iteration + 1`, cap at 5):

### A. Review

1. Fetch diff: `gh pr diff <N>`.
2. Invoke **pr-reviewer** with diff and standards — same 8-dimension rubric; overall =
   **min** of dimensions.
3. Update state file: scores, blockers, append to `history`.
4. **Confirm with operator** — show summary. Wait for approval to post PR comment.
5. Post comment: `gh pr comment <N> --body-file <file>`.

### B. Stop checks

- If **overall = 5** → report success (MERGE-READY). Stop.
- If **iteration = 5** without 5/5 → summarize remaining blockers. Stop.
- Otherwise **confirm with operator**: continue fixing / stop / accept current score.

### C. Fix and push (only if operator confirms continue)

1. Address **every blocker** from the review. Optionally address suggestions if aiming
   for 5/5.
2. Run the **full test suite** — must be green before push.
3. **Confirm with operator** before push.
4. `git push` to the **same branch** (the PR updates automatically).
5. Increment `iteration` in state file.

Return to **A** for the next iteration unless stopped.

## Confirm gates (mandatory)

Ask the operator before:

- Starting each iteration's review (except iteration 1 if operator already invoked this command)
- Posting each PR comment
- Starting fixes after a review
- Each `git push`

## Relationship to other commands

- **`/review-loop`** — local diff, no GitHub, no scoring; run before `/create-pr`.
- **`/review-pr`** — one-shot review + comment; no fix loop.
- **`/pr-review-loop`** — this command; full cycle until 5/5 or cap.

## Output

Report each iteration: number, overall score, limiting dimensions, blockers fixed, push
status, and final state (MERGE-READY, capped, or operator stopped).
