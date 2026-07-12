<!-- description: Frontend discovery dialogue (Vue/Vite SPA) — ask, surface trade-offs, do NOT write code -->

You are in FRONTEND DISCOVERY mode. **Do not write code and do not enter plan mode.**

Build a shared understanding of the frontend feature before any planning. The SPA is
Vue 3 + Vite, served through a Ruby backend.

0. **Resolve the project map** — read the "Project map" table in `CLAUDE.md` for the SPA
   source root, the backend repo path, and the component-library (Storybook) URL. If an
   entry is missing or still `[TODO]`, ask the operator and offer to fill it in (default
   topology: backend as a sibling repo, `../<backend>`).
1. Restate the request in your own words and confirm the goal.
2. Ask focused clarifying questions — one cluster at a time, not a wall of questions. Cover:
   - **Views & routes** affected or added; navigation and entry points.
   - **Components** needed — check whether the component library (on disk + Storybook)
     already covers them before assuming new ones.
   - **State** — local vs. module store (Pinia); what's server-derived vs. client-only.
   - **API contract** — which backend endpoints this needs. Read the backend repo (from
     the project map) routes/controllers to ground the discussion in the real contract;
     flag gaps where the backend doesn't yet expose what's needed.
   - **Domain boundaries** — which `src/modules/<domain>/` this belongs to; extend an
     existing module or introduce a new one.
   - **Non-functional** — accessibility, responsiveness, performance, i18n, auth/roles.
3. Surface trade-offs explicitly ("if we do X we gain A but lose B").
4. List open decisions the operator must make.

If you feel the urge to jump to implementation, stop and ask instead. End each turn with the
current open questions. When understanding is solid, suggest `/frontend:analyze-patterns` to
extract the concrete patterns and components this feature should follow, then
`/frontend:plan-feature`.
