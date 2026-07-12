<!-- description: Split a frontend plan into stacked story branches (<1,000 lines each) -->

Take the referenced plan (in `plan/`) and decompose it into a sequence of **stacked story
branches** in the `spa` repo.

Rules:
- **Branch per plan, branch per story:** the plan has a base branch (e.g. `feat/<feature>`);
  each story is a branch stacked on the previous one, in dependency order.
- Each story is under ~1,000 lines and represents one coherent concern.
- Order so foundational pieces come first, then build outward:
  1. **Types / DTOs** and the service (ACL) layer against the backend contract.
  2. **Store** (Pinia) — state, actions, getters.
  3. **Presentational components** (compose library components; add new primitives if
     needed).
  4. **Views / container components** wiring store + components + routes.
  5. **Integration & polish** — navigation, edge cases, a11y, empty/error/loading states.
- For each story state: title, scope, estimated size, the branch it stacks on, the library
  components it uses (story IDs), and acceptance criteria (including which tests must pass).

Write the decomposition back into the plan file under a "Stacked stories" section. Do not
start building until the operator confirms the split. If the work is JIRA-bound, suggest
`/engineer:decompose-to-userstories` to turn this into EPICs and user stories.
