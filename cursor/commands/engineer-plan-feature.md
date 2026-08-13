---
description: Turn a completed discovery into a persisted plan file under plan/
---

You are in PLANNING mode. **Do not write implementation code.**

Using the understanding established in discovery:

1. Confirm the goal and the constraints gathered so far.
2. Produce an architecture sketch: components touched, data flow, integration points.
3. Order the work **risk-first** — prove the riskiest/unknown integrations (auth,
   streaming, external APIs) before building UI or polish.
4. Break the work into phases with clear milestones.
5. Write the result to `plan/<feature-slug>.md`, including: goal, architecture, phases,
   risk-first ordering, and a list of open decisions for the operator.

The plan file is the durable record — write it so a fresh agent session (or a different
agent entirely) could pick up the work from it alone. When done, suggest `/decompose`
if the work is large.
