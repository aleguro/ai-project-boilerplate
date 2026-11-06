---
name: driver
description: Top-level orchestrator for a whole feature. Coordinates spec → api → app → qa → stats end-to-end, invoking the right skill per layer, gating on ai_blob_score/spec_drift between layers, and leaving exactly one clean commit per layer in the feature branch. Use instead of chaining spec-driven-development → tdd-loop → e2e → /save → pr-stack by hand.
triggers:
  - /ship-feature
  - /driver
---

# Driver

## Philosophy

Each skill in this repo (`spec-driven-development`, `tdd-loop`, `e2e`, `churn`, `obsidian-integration`) knows how to do **one** layer well. Nobody coordinates them. Without a driver, a feature becomes: run skill → stop → human decides what's next → run skill → stop → repeat — and nothing stops a layer from bleeding into the next until a human notices at review time.

The driver is that missing coordinator. It owns the sequence, the gates between layers, and the commit boundaries. The underlying skills don't change — this wraps them.

**One feature = one branch = 5 layers = 5 clean commits (minimum) = 1 PR (per stack, via `make pr-stack`).**

---

## The 5 layers

| # | Layer | Does | Delegates to | Commit prefix |
|---|-------|------|---------------|----------------|
| 1 | **spec** | Actors, use cases, stages/tasks, graphify context | `spec-driven-development` (Steps 1–2) | `spec(<feature>):` |
| 2 | **api** | Tasks tagged `rails`/`python` that define a contract (endpoints, schemas, jobs) | `tdd-loop` + `stacks/rails` or `stacks/python` | `feat(<feature>): api —` |
| 3 | **app** | Tasks tagged `react` (or UI-facing rails views) that consume the contract | `tdd-loop` + `stacks/react` | `feat(<feature>): app —` |
| 4 | **qa** | End-to-end coverage of the use cases | `e2e` (planner → generator → healer) | `test(<feature>): e2e —` |
| 5 | **stats** | Metrics, brain update, PR | `churn`, `obsidian-integration`, `/save` semantics | `chore(<feature>): stats —` |

A feature with no UI skips layer 3. A feature with no new contract (pure UI, pure script) skips layer 2. Never skip 1, 4, or 5.

---

## Workflow

### 0. Resume check

Before doing anything: does `brain/Features/<feature>.md` already exist? If yes, read it — `status:` and the ticked tasks tell you which layer to resume from. Don't restart a finished layer.

### 1. Layer: spec

1. Load `spec-driven-development`, run Steps 1 (ticket + spec) and 2 (graphify context) only.
2. Group the spec's tasks by layer using their `Stack:` tag:
   - `rails` / `python` tasks that define request/response contracts, schemas, or background jobs → **api**
   - `react` tasks, and any `rails` view-only tasks → **app**
3. Commit: `spec(<feature>): <one-line summary>`
4. **Gate:** none yet — this is the baseline. Run `scripts/metric-logger.sh report` once now anyway so there's a zero-point to diff against later.

### 2. Layer: api (skip if no backend-contract tasks)

1. Apply the parallelization check from `spec-driven-development` (Step 4) **within this layer only**: 2+ api tasks on different stacks → parallel agents in worktrees; same stack or dependent → sequential, same session.
2. For each task: load the matching `stacks/<stack>` skill, run `tdd-loop`, land on green.
3. Do **not** commit per task here — that's `tdd-loop`'s own concern when run standalone. Under the driver, let all api tasks land, then make **one** commit for the layer: `feat(<feature>): api — <tasks summary>`.
4. **Gate before moving to app:**
   ```bash
   scripts/metric-logger.sh report
   ```
   Read the printed `alerts`:
   - `ai_blob_score too high` → stop. Run `/ponytail-review` on this layer's diff (ponytail is installed project-wide — `.claude/settings.json`) as the refactor pass, then re-run the report until clear.
   - Any file changed outside this layer's task scope → `spec_drift`. Stop, ask the user: amend the spec to cover it, or revert the out-of-scope change. Never let it pass silently into the commit.

### 3. Layer: app (skip if no UI/consumer tasks)

Same mechanics as **api**: parallelize across stacks if independent, run `tdd-loop` per task, one commit for the layer (`feat(<feature>): app — <tasks summary>`), same gate (`ai_blob_score`, `spec_drift`) before advancing.

If the spec touches UI and no mockup exists yet, run `spec-driven-development` Step 3 (mockup) first and fold its commit into this layer.

### 4. Layer: qa

1. Load `e2e`. Run the three-agent pipeline (planner → generator → healer) against the use cases from the spec.
2. Commit: `test(<feature>): e2e — <scenarios covered>`
3. **Gate:** all specs green. A red spec after the healer's pass means stop and surface it — the driver does not paper over a failing test by narrowing scope.

### 5. Layer: stats

1. Run the `/save` sequence: `scripts/metric-logger.sh report`, then `make churn-report FEATURE=<feature>` if the feature is shipping.
2. Load `obsidian-integration` and update `brain/Features/<feature>.md` (status → `shipped`, tick tasks, wikilinks) plus any domain folder the feature touched (`Architecture/`, `Codebase/`, `Database/`, `APIs/`, `Decisions/`).
3. Commit: `chore(<feature>): stats — metrics + brain update`
4. Run `make pr-stack` — one PR per stack that changed, each PR body auto-includes the metrics table from step 1.

---

## Gates, summarized

Between **every** api/app layer transition, and once more before stats:

```bash
scripts/metric-logger.sh report
```

Stop and resolve before continuing if the report's `alerts` contains:
- `ai_blob_score too high` (threshold: 20) — refactor, don't ship it hoping review catches it
- a file outside the current layer's declared task scope — this is `spec_drift` (threshold: 10%); the metric file leaves this as `"check manually"`, so the driver's job is to actually do that comparison against the spec's `Stages and Tasks` section before committing, not skip it because the field says "manually"

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
