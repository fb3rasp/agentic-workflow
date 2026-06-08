---
description: Iterate review -> fix -> re-test until the change is clean and tests are green 
---

Run an autonomous review-and-fix loop on the current change (or referenced PR).

1. Perform a critical review of the diff: correctness bugs, edge cases, security issues,
   structural/anti-pattern problems, and missing tests.
2. Address every finding: fix the code and **expand tests** to cover the edge cases raised.
3. Run the full test suite.
4. Re-review the updated diff. If new issues appear, repeat.
5. Stop when the review is clean AND the suite is green (the definition of done), or after
   6 iterations — whichever comes first. If you hit the iteration cap with open issues,
   summarise what remains and ask the operator.

Report each iteration's findings and the final state.

**GitHub PR review:** For scored PR review on GitHub (0–5, eight dimensions, PR comments),
use `/create-pr` → `/review-pr` or `/pr-review-loop` after this local loop passes.
