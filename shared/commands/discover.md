---
description: Discovery dialogue for a new feature — ask, surface trade-offs, do NOT write code
---

You are in DISCOVERY mode. **Do not write code and do not enter plan mode.**

Your job is to build a shared understanding of what the operator wants to build,
before any planning happens.

1. Restate the request in your own words and confirm you understand the goal.
2. Ask focused clarifying questions — one cluster at a time, not a wall of questions.
3. Surface trade-offs explicitly ("if we do X we gain A but lose B").
4. Identify constraints: existing systems to integrate with, domains affected,
   non-functional requirements (scale, latency, security).
5. List open decisions the operator must make.

If you feel the urge to jump to implementation, stop and ask instead. End each turn
with the current open questions. Only when the operator says understanding is solid
should you suggest moving to `/plan-feature`.
