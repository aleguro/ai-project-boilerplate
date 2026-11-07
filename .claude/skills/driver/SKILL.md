---
name: driver
description: Top-level orchestrator for a whole feature. Coordinates spec → api → app → qa → stats end-to-end, invoking the right skill per layer, gating on ai_blob_score/spec_drift between layers, and leaving exactly one clean commit per layer in the feature branch. Use instead of chaining spec-driven-development → tdd-loop → e2e → /save → git push-pr by hand.
triggers:
  - /ship-feature
  - /driver
---

# Driver

## Philosophy

Each skill in this repo (`spec-driven-development`, `tdd-loop`, `e2e`, `churn`, `obsidian-integration`) knows how to do **one** layer well. Nobody coordinates them. Without a driver, a feature becomes: run skill → stop → human decides what's next → run skill → stop → repeat — and nothing stops a layer from bleeding into the next until a human notices at review time.

The driver is that missing coordinator. It owns the sequence, the gates between layers, and the commit boundaries. The underlying skills don't change — this wraps them.

**One feature = one branch = 5 layers = 5 clean commits (minimum) = 1 PR, via `git push-pr`.**

---

## The 5 layers

| # | Layer | Does | Delegates to | Commit prefix |
|---|-------|------|---------------|----------------|
| 1 | **spec** | Actors, use cases, stages/tasks, graphify context, mockup (conditional) + brain/Features + brain/Decisions — then a human refinement loop before anything else runs | `spec-driven-development` (Steps 1–3, Step 3 conditional), `obsidian-integration` | `spec(<feature>):` (+ `design: mockup <feature>` if a mockup was made) |
| 2 | **api** | Tasks tagged `rails`/`python` that define a contract (endpoints, schemas, jobs) + brain/Database + brain/APIs | `tdd-loop` + `stacks/rails` or `stacks/python`, `obsidian-integration` | `feat(<feature>): api —` |
| 3 | **app** | Tasks tagged `react` (or UI-facing rails views) that consume the contract + brain/Architecture + brain/Codebase | `tdd-loop` + `stacks/react`, `obsidian-integration` | `feat(<feature>): app —` |
| 4 | **qa** | End-to-end coverage of the use cases (no brain update) | `e2e` (planner → generator → healer) | `test(<feature>): e2e —` |
| 5 | **stats** | Metrics, final brain catch-all, PR | `churn`, `obsidian-integration`, `/save` semantics | `chore(<feature>): stats —` |

A feature with no UI skips layer 3. A feature with no new contract (pure UI, pure script) skips layer 2. Never skip 1, 4, or 5.

---

## Workflow

### 0. Resume check

Before doing anything: does `brain/Features/<feature>.md` already exist? If yes, read its `layers_committed:` frontmatter field — a list like `[spec, api]` — and resume from the next layer that isn't in it. Ticked tasks alone aren't enough to tell: a task can be green while the one commit for its layer never landed (session cut mid-step), so `layers_committed` is the one source of truth for "is this layer actually done." Don't restart a layer already in that list.

If a ticket/spec file exists on disk but `spec` isn't in `layers_committed:` yet, the previous session drafted a spec that was never approved and never committed — don't rewrite it from scratch. Re-present what's already there (and the mockup, if one was made) and resume the human checkpoint from there.

### 1. Layer: spec

1. Load `spec-driven-development`, run Steps 1 (ticket + spec) and 2 (graphify context).
2. **Mockup, only if the spec actually needs one** — apply the same trigger `spec-driven-development` Step 3 already defines (the spec mentions UI, form, modal, screen, panel, or visual list). If it doesn't trigger, skip Step 3 entirely: don't invoke `frontend-design`, don't create a `docs/designs/` entry. Judge this from what the spec's use cases actually describe, not from the stack tag alone — a `react` task can still be a pure data/CLI client with no screen.
3. Group the spec's tasks by layer using their `Stack:` tag:
   - `rails` / `python` tasks that define request/response contracts, schemas, or background jobs → **api**
   - `react` tasks, and any `rails` view-only tasks → **app**
4. **Human checkpoint — a hard stop, not a prompt you can talk yourself past.** Present the ticket, the spec (actors, use cases, stages/tasks), and the mockup screenshot if one was made, then end your turn without calling another tool — use `AskUserQuestion` or just stop and wait. This is exactly the "decision only the human can make" case that overrides any bias toward not pausing for confirmation: never read a short reply, a topic change, an interruption, or the mere fact that nothing objected as approval. Running `/ship-feature` again on a feature whose spec file already exists and isn't in `layers_committed:` is NOT itself approval, however long ago it was drafted — it means go back to this checkpoint, not past it.
   - If the human asks for changes (to the spec text, the task breakdown, or the mockup): revise, re-present, and repeat. This is a loop, not a single round — keep refining until the human's reply is an explicit, affirmative go-ahead (e.g. "approved," "yes, proceed," "looks good, continue") said about this spec specifically.
   - Only on that explicit approval, continue to step 5 — in a new turn, after the human has actually replied.
5. Commit: `spec(<feature>): <one-line summary>` (and `design: mockup <feature>` first, as its own commit, if a mockup was made in step 2).
6. Load `obsidian-integration`. Update `brain/Features/<feature>.md` to reflect the spec just written (the ticket was created in Step 1a of `spec-driven-development` — this updates it if anything changed). If the spec's **Design Decisions** section has content, create or update the relevant note in `brain/Decisions/` (one ADR per non-obvious decision).
7. **Gate:** none yet — this is the baseline. Run `scripts/metric-logger.sh report` once now anyway so there's a zero-point to diff against later.
8. Add `spec` to `layers_committed:` in `brain/Features/<feature>.md`.

### 2. Layer: api (skip if no backend-contract tasks)

1. Apply the parallelization check from `spec-driven-development` (Step 4) **within this layer only**: 2+ api tasks on different stacks → parallel agents in worktrees; same stack or dependent → sequential, same session.
2. For each task: load the matching `<stack>` skill, run `tdd-loop`, land on green.
3. Do **not** commit per task here — that's `tdd-loop`'s own concern when run standalone. Under the driver, let all api tasks land, then make **one** commit for the layer: `feat(<feature>): api — <tasks summary>`.
4. Load `obsidian-integration`. Update brain folders based on what this layer touched:
   - Migrations or schema changes → update `brain/Database/` (table changes, new columns, index rationale)
   - New or changed endpoints, webhooks, or external service integrations → update `brain/APIs/`
   - If neither applies, skip this step.
5. **Gate before moving to app** — run the check in "Gates, summarized" below. On pass, add `api` to `layers_committed:`.

### 3. Layer: app (skip if no UI/consumer tasks)

The mockup (if any) was already made and approved back in layer 1 — nothing design-related happens here, only implementation against it.

1. Apply the parallelization check: 2+ app tasks on different stacks → parallel agents in worktrees; same stack or dependent → sequential, same session.
2. For each task: load the matching `stacks/<stack>` skill, run `tdd-loop`, land on green.
3. One commit for the layer: `feat(<feature>): app — <tasks summary>`.
4. Load `obsidian-integration`. Update brain folders based on what this layer touched:
   - New services, data flows, or cross-component interactions → update `brain/Architecture/`
   - New patterns, conventions, or modules introduced → update `brain/Codebase/`
   - If neither applies, skip this step.
5. **Gate before moving to qa** — run the check in "Gates, summarized" below. On pass, add `app` to `layers_committed:`.

### 4. Layer: qa

1. Load `e2e`. Run the three-agent pipeline (planner → generator → healer) against the use cases from the spec.
2. Commit: `test(<feature>): e2e — <scenarios covered>`
3. **Gate:** all specs green. A red spec after the healer's pass means stop and surface it — the driver does not paper over a failing test by narrowing scope.
4. No brain update — tests do not generate domain knowledge. Add `qa` to `layers_committed:`.

### 5. Layer: stats

1. Run the `/save` sequence: `scripts/metric-logger.sh report`, then `make churn-report FEATURE=<feature>` if the feature is shipping.
2. Load `obsidian-integration` and update `brain/Features/<feature>.md` (status → `shipped`, tick tasks, wikilinks, `layers_committed:` → add `stats`) plus any domain folder **not already updated by a prior layer** (`Architecture/`, `Codebase/`, `Database/`, `APIs/`, `Decisions/`). Earlier layers update folders incrementally as they land — stats is the catch-all for anything that slipped through or for features where a layer was skipped.
3. Commit: `chore(<feature>): stats — metrics + brain update`
4. Run `git push-pr` — pushes the branch and opens the one PR for the feature, body auto-includes the metrics from step 1 (graphify calls, spec drift, test coverage, token drift).

---

## Gates, summarized

Before moving from **api** to **app**, from **app** to **qa**, and once more before **stats**:

```bash
scripts/metric-logger.sh report
```

Stop and resolve before continuing if the report's `alerts` contains:
- `ai_blob_score too high` (threshold: 20) — run `/ponytail-review` on this layer's diff as the refactor pass (ponytail is installed project-wide, `.claude/settings.json`), then re-run the report until clear. Refactor, don't ship it hoping review catches it later.
- `spec_drift: check manually — ...` — the script only tells you a spec file exists and files changed; it does not know the task scope. Actually do the comparison: read the spec's `Stages and Tasks` section for the layer you're closing and check every changed file lands on one of its tasks. If one doesn't, stop — amend the spec to cover it, or revert the out-of-scope change. Never let it pass silently into the commit because the alert didn't name the file for you.

These are the same two thresholds already in `CLAUDE.md`'s Rules section — the driver is what actually enforces them mid-flight instead of at review time.

---

## Model routing

Unchanged from `spec-driven-development`'s table — the driver doesn't add a routing decision of its own, it just calls into layers that already know their model:

| Layer | Model | Effort |
|-------|-------|--------|
| spec | Opus or fork | high |
| api / app (tdd-loop) | Sonnet | medium |
| qa (e2e agents) | Sonnet | medium |
| stats (report/churn, brain writes) | Haiku | low |

---

## What the driver does not do

- It does not replace `tdd-loop`'s red→green discipline — it only changes who commits and when.
- It does not invent new stats — it reads what `metric-logger.sh` already computes.
- It is not required. Any layer's skill can still be invoked standalone for a one-off fix; the driver is for the "ship a whole feature" case the user actually asks for most of the time.
