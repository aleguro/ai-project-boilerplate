---
name: spec-driven-development
description: Minimalist spec-driven workflow oriented to human development practices. Starts from actors and use cases, plans in minimal deliverable tasks per stage, implements with TDD, validates with metrics. Use at the start of any feature.
---

# Spec-Driven Development

## Philosophy

The spec is not documentation — it is the contract between what the business needs and what the code does.
Every task in the spec must be **deliverable, testable, and independent**.
The model does not improvise: it writes no line of code that is not in the spec.

---

## Workflow

```
1. Write the spec  (create Feature ticket + actors → use cases → stages → tasks)
2. Graphify context (auto-updated on every commit; query before touching a module)
3. UI? → mockup    (if the spec touches UI)
4. TDD loop        (per task: red → green → commit → graphify auto-updates)
5. Brain update    (/save — metrics generated automatically)
6. PR per stack    (make pr-stack)
```

Graphify updates itself automatically after every `git commit` (post-commit hook installed by bootstrap). Metrics are generated automatically by `/save`. **The user's only manual steps are: write estimates (`Human: Xh`), commit code, and say `/save`.**

---

## Step 1: Create the Feature ticket + Spec

### 1a — Create the Feature ticket in the brain

Before writing the spec, create a ticket in `brain/Features/<feature-name>.md`. This is the persistent record — it lives in the vault and tracks status across sessions.

```markdown
---
title: <Feature Name>
tags: [feature, <topic>]
created: YYYY-MM-DD
updated: YYYY-MM-DD
status: draft
type: feature
spec: docs/superpowers/specs/YYYY-MM-DD-<feature>.md
branch: feature/<name>
---

# <Feature Name>

## Summary

<One paragraph: what this does and why it matters.>

## Actors

- **<Actor>** — <role>

## Acceptance criteria

- [ ] <criterion derived from use cases>

## Tasks

_Populated from the spec stages — copy stage/task list here after writing the spec._

## Decisions

_Wikilinks to ADRs in [[Decisions/]] created during this feature._

## Related

_Wikilinks to [[Architecture/]], [[Codebase/]], [[Database/]] notes this feature touches._
```

After creating the ticket, update `brain/Features/index.md` to add a wikilink to it.

### 1b — Write the Spec

Save to `docs/superpowers/specs/YYYY-MM-DD-<feature>.md`. Copy the task list into the Feature ticket once the stages are defined.

```markdown
# Spec: <feature name>

**Date:** YYYY-MM-DD
**Branch:** feature/<name>
**Stack:** rails | react | python | (all)
**Ticket:** brain/Features/<feature-name>.md

---

## Actors

| Actor | Role |
|-------|------|
| Registered user | Who initiates the action |
| External system | Third-party API being consumed |
| Admin | Who approves or configures |

---

## Use Cases

### UC-01: <Use case name>
- **Actor:** Registered user
- **Precondition:** The user has an active account
- **Main flow:**
  1. The user does X
  2. The system validates Y
  3. The system executes Z
  4. The user sees the result
- **Alternative flows:**
  - 2a. Y is not valid → show error E
- **Postcondition:** The system records W

### UC-02: ...

---

## Stages and Tasks

Each stage is a set of deliverable tasks. Each task = 1 PR.

### Stage 1: <name> (minimum viable)

- [ ] **T1.1** — <one-line description> | Stack: rails | Size: S/M/L | Human: Xh
- [ ] **T1.2** — <one-line description> | Stack: react | Size: S/M/L | Human: Xh

### Stage 2: <name> (complete the flow)

- [ ] **T2.1** — ... | Stack: ... | Size: M | Human: 3h

### Stage 3: <name> (edge cases + observability)

- [ ] **T3.1** — ... | Stack: ... | Size: S | Human: 1h

---

## Acceptance Criteria

- [ ] UC-01 works end-to-end in staging
- [ ] Tests cover the main flow + alternative flows for each UC
- [ ] No regressions in the existing suite
- [ ] Metrics within range (see Step 5)

---

## Design Decisions

_Record non-obvious decisions made during the spec here._
```

---

## Step 2: Graphify Context

The graph is always up to date — bootstrap installed a post-commit hook that runs `graphify-update` after every commit automatically.

Before touching an existing module, query the graph:

```bash
graphify query "<feature topic>"
graphify explain "<MostRelevantModule>"
```

Record in the spec (Design Decisions section) which existing modules will be extended.

---

## Step 3: UI — Mockup (only if applicable)

**Trigger:** the spec mentions UI, form, modal, screen, panel, or visual list.

1. Invoke skill `frontend-design`
2. Save HTML to `docs/designs/<branch>/<feature>.html`
3. Screenshot with `claude-in-chrome` → save PNG
4. Commit: `git commit -m "design: mockup <feature>"`

---

## Step 4: TDD Loop

### Parallelization decision

Before starting implementation, check task independence for the current stage:

```
Are there 2+ tasks in this stage targeting DIFFERENT stacks?
  YES → launch parallel agents (one per task)
  NO  → run sequentially in this session
```

Tasks are independent when:
- They target different stacks (rails ≠ react ≠ python)
- Neither task's output is an input to the other
- They don't touch the same files

### Parallel execution (different stacks)

For each independent task, spawn a fresh agent with its own worktree:

```
Agent per task:
  - subagent_type: "fresh"
  - isolation: "worktree"
  - model: "sonnet"
  - prompt: |
      Implement [T1.x]: <one-line description>
      Branch: feature/<feature>
      Stack: <rails|react|python>

      Steps:
      1. Load skill stacks/<stack>
      2. Load skill tdd-loop
      3. Run the full tdd-loop for this task
      4. Commit: feat(T1.x): <description>
      5. Mark task [x] in docs/superpowers/specs/<spec-file> AND in brain/Features/<feature>.md
      6. Log: scripts/metric-logger.sh task T1.x green <human_hours>   # e.g. 4h from the task's Human: field
```

Wait for all parallel agents to finish before starting the next stage.

### Sequential execution (same stack or dependent)

1. Create branch: `git checkout -b feature/<feature>-T1.1`
2. Load the corresponding stack skill (`stacks/rails`, `stacks/react`, `stacks/python`)
3. Run the TDD loop skill (`tdd-loop`)
4. On green: `git commit -m "feat(T1.1): <description>"`
5. Mark the task as `[x]` in the spec AND in `brain/Features/<feature>.md`
6. Log: `scripts/metric-logger.sh task T1.1 green 4h`   # replace 4h with the task's Human: estimate
7. Repeat for T1.2, T2.1, …

**Rule:** do not start T1.2 until T1.1 is green and committed.

### Model routing

| Task type | Model | Effort | Rationale |
|-----------|-------|--------|-----------|
| Spec + graphify context | Opus or fork | high | Needs full business context, ambiguity to resolve |
| TDD red→green | Sonnet | medium | Fast iteration, scope already pinned by the spec |
| Refactor | Sonnet | medium | Mechanical, low ambiguity |
| Code review | Sonnet | high | Multi-file reasoning, worth catching subtle issues |
| Graphify queries only | Haiku | low | Read-only lookups |

---

## Step 5: Metrics

**Automatic — no manual steps needed.**

`/save` generates session metrics and saves them to `brain/Metrics/` automatically. If this session shipped a feature, `/save` also generates the AI vs human comparison.

The only thing to fill in manually is `Human: Xh` on each task — this is the estimate that powers the comparison. It takes 5 seconds per task and is the only input the automation can't derive on its own.

Alerts to watch for (Claude will flag these during the session):
- `ai_blob_score > 20` — functions over 40 lines without tests
- `spec_drift` — code outside the spec's scope

---

## Step 6: Brain Update (`/save`)

Tell Claude `/save` — it handles everything automatically:
- Updates `brain/Features/<feature>.md` (status, ticked tasks, wikilinks)
- Updates relevant domain folders (Architecture, Codebase, Database, etc.)
- Generates session metrics → `brain/Metrics/session-YYYY-MM-DD-<branch>.md`
- If the feature is shipped: generates AI vs human comparison → `brain/Metrics/<feature>-comparison.md`
- `git commit`

Domain folders updated per what changed:

| What changed | Brain folder |
|--------------|-------------|
| New service or data flow | `brain/Architecture/` |
| New module or pattern | `brain/Codebase/` |
| Schema or migration | `brain/Database/` |
| New external integration | `brain/APIs/` |
| Non-obvious tech decision | `brain/Decisions/` (ADR) |
| Setup changed | `brain/Install/` |
| Infra or CI changed | `brain/Infra/` |

Each note in `brain/Decisions/` follows this format:
```markdown
# ADR-NN: <title>

**Date:** YYYY-MM-DD
**Status:** accepted | superseded | deprecated

## Context
What situation forced this decision.

## Decision
What we decided.

## Consequences
What becomes easier or harder as a result.
```

Use skill `obsidian-integration` to read/write vault notes.

---

## Step 7: PR per Stack

```bash
scripts/push-pr-stack.sh
```

Creates one PR per stack that had changes. Each PR includes:
- List of completed spec tasks
- Session metrics
- Link to spec
- Mockup screenshots (if any)
