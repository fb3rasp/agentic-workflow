---
description: Frontend structural pass — component split, composables, service layer, DDD module isolation
---

Inspect the code changed in this session (or the path given) for frontend structural smells
and refactor them, **without changing behaviour**.

Focus on:
1. **Component library first** — replace hand-rolled UI with existing library components
   where one fits (check on-disk source + Storybook). Flag bespoke components that duplicate
   a library primitive.
2. **Container vs. presentational** — move data-fetching and state out of presentational
   components into container components or composables; keep presentational components pure
   (props in, events out).
3. **Composables** — extract repeated reactive logic into `composables/` (`use…`).
4. **Service / ACL layer** — route all backend calls through a module's `services/` layer;
   no `fetch`/axios or raw backend DTOs inside components. Map payloads to domain types.
5. **Duplication** — extract repeated logic/markup into shared components or composables.
6. **DDD module isolation** — no module reaching into another module's store or internals;
   route cross-module access through typed public APIs or events. Ensure files map cleanly
   to `src/modules/<domain>/`.

Run the test suite (Vitest) after refactoring and report what changed and why. If a refactor
would change behaviour, stop and ask first.
