---
description: Implement a plan (or its next stacked PR) by routing each Rails layer to its specialist subagent
---

Build the current plan phase (or the referenced plan/PR) by dispatching implementation
work to layer-specific subagents instead of writing every layer yourself.

1. Resolve what to build: the referenced `plan/<feature-slug>.md`, and — if it has been
   through `/decompose` — the specific stacked PR/phase to implement now. If neither is
   given, ask which plan/phase.
2. From the plan's architecture sketch, break this phase into concrete per-layer work
   items: models/migrations, services, background jobs, controllers/routes, API endpoints,
   plus anything outside those five (views, GraphQL, JS) that you'll implement directly.
   For a feature spanning several layers with non-obvious interfaces between them, dispatch
   `rails-architect` first to produce the coordination sketch (layer → specialist →
   deliverable → depends-on) before proceeding — it plans the delegation, it does not
   execute it.
3. Dispatch layers with an available specialist, **in dependency order** — models and
   migrations first; then services and jobs (both depend only on models, and rarely on
   each other, so dispatch them in parallel when both are needed); then controllers and
   API last (they call into services/jobs/models, so those interfaces must exist first):
   - `rails-models` — ActiveRecord models, associations, migrations
   - `rails-services` — service objects / business logic
   - `rails-jobs` — ActiveJob background jobs, queues, retry strategy
   - `rails-controllers` — controllers, routes, request handling
   - `rails-api` — versioned JSON API endpoints, serializers

   Each dispatch must be self-contained: state exactly which files/behavior are needed and
   any interface the layer depends on (e.g. the service's `#call` signature a controller
   will invoke, or the job class a controller will enqueue) — a subagent has no memory of
   the plan discussion, only what you give it. Layers with no interdependency (e.g. two
   unrelated services, or services alongside jobs) may be dispatched in parallel; dependent
   layers must run sequentially so downstream agents see real upstream interfaces, not
   assumed ones.
4. Implement any remaining layers (views, GraphQL, JS/Stimulus, etc.) yourself — there is
   no specialist agent for them yet.
5. Run the full test suite. Report which layers were touched, which subagent (or you)
   implemented each, and any interface decisions the operator should know about.

This is implementation, not review — findings and fixes belong to `/review-loop`, which
you should suggest running next.
