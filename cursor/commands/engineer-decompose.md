---
description: Split a plan into stacked PRs with a <1,000-line budget each
---

Take the referenced plan (in `plan/`) and decompose it into a sequence of **stacked
pull requests**.

Rules:
- Each PR must be under ~1,000 lines and represent one coherent concern.
- Each PR builds on the branch of the previous one (stacked), in dependency order.
- Order so that foundational contracts/data structures come first, then persistence,
  then UI, then integration/polish.
- For each PR, state: title, scope, estimated size, the branch it stacks on, and its
  acceptance criteria (including which tests must pass).

Write the decomposition back into the plan file under a "Stacked PRs" section. Do not
start building until the operator confirms the split.
