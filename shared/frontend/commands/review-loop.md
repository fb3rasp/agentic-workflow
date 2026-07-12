<!-- description: Iterate review -> fix -> re-test on a frontend change until clean and green -->

Run an autonomous review-and-fix loop on the current frontend change (or referenced PR).
Use the **frontend-reviewer** subagent for the review pass.

1. Perform a critical review of the diff:
   - **Correctness** — reactivity bugs, stale closures, prop/emit mismatches, key/rendering
     issues, error/loading/empty states.
   - **Component-library-first** — bespoke UI that duplicates an existing library component;
     components not composed from the library where they should be.
   - **Accessibility** — semantics, labels, keyboard nav, focus management, ARIA where
     needed, colour-independent state.
   - **Typing & props** — typed props/emits, no `any` leaks, domain types (not raw backend
     DTOs) in components.
   - **State discipline** — Pinia store use vs. local state; no cross-module store reach;
     side effects in the right place.
   - **Service layer** — backend calls go through the ACL layer, not inline in components.
   - **Tests** — Vitest/component coverage of the happy path AND edge cases.
2. Address every finding: fix the code and **expand tests** to cover the edge cases raised.
3. Run the full test suite (Vitest).
4. Re-review the updated diff. If new issues appear, repeat.
5. Stop when the review is clean AND the suite is green (the definition of done), or after
   6 iterations — whichever comes first. If you hit the cap with open issues, summarise
   what remains and ask the operator.

Report each iteration's findings and the final state.

**GitHub PR review:** for a scored PR review on GitHub, use `/engineer:create-pr` →
`/engineer:review-pr` or `/engineer:pr-review-loop` after this local loop passes.
