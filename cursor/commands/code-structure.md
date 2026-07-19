---
description: Dedupe pass — pull repeated logic into the service layer, enforce domain isolation
---

Inspect the code changed in this session (or the path given) for structural smells and
refactor them, **without changing behaviour**.

Focus on:
1. **Duplication** — find repeated logic and extract it into a shared service/module.
2. **Service layer** — move domain logic out of controllers/handlers/UI components into
   the service layer. Keep runtime mechanics separate from domain logic.
3. **Domain isolation** — flag and fix cross-domain coupling (shared tables, direct
   reaches into another domain's internals). Route cross-domain access through APIs or
   events.
4. **Naming & boundaries** — ensure modules map cleanly to domains.

Run the test suite after refactoring and report what changed and why. If a refactor
would change behaviour, stop and ask first.
