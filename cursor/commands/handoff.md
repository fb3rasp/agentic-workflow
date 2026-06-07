---
description: Persist a context handoff to disk before clearing the thread 
---

Write a concise handoff so a fresh thread can resume this work without re-deriving context.

Create or update `plan/<feature-slug>.handoff.md` with:
1. **Goal** — what we're building and why.
2. **State** — what's done, what's in progress, what's left.
3. **Key decisions** — choices made and their rationale.
4. **Open questions** — anything unresolved.
5. **Next step** — the single most important thing to do next.
6. **Pointers** — relevant files, branches, and the plan file.

Keep it tight and factual. After writing it, tell the operator it's safe to clear the
thread and resume with this file.
