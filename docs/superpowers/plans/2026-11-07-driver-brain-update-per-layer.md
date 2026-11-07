# Driver — Brain Update Per Layer: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add inline Obsidian brain updates at the close of each driver layer so the vault reflects work-in-progress state, not just the final shipped feature.

**Architecture:** Single file edit — `.claude/skills/driver/SKILL.md`. Each layer's workflow section gets a brain-update step inserted after the layer commit (before the gate or layers_committed write). Layer 5 (stats) is updated to scope its update to folders not yet covered.

**Tech Stack:** Markdown only — no executable code.

---

## File Map

| File | Action |
|------|--------|
| `.claude/skills/driver/SKILL.md` | Modify — 5 targeted edits, one per layer |

---

### Task 1: Layer 1 (spec) — add brain update sub-step

**Files:**
- Modify: `.claude/skills/driver/SKILL.md` (Layer 1 section, lines 41–49)

The current Layer 1 step 4 is the metric-logger baseline gate and step 5 marks `layers_committed`. We insert a brain update between commit (step 3) and the gate (step 4).

**New Layer 1 steps 4–6 (replacing current 4–5):**

```markdown
4. Load `obsidian-integration`. Update `brain/Features/<feature>.md` to reflect the spec just written (the ticket was created in Step 1a of `spec-driven-development` — this updates it if anything changed). If the spec's **Design Decisions** section has content, create or update the relevant note in `brain/Decisions/` (one ADR per non-obvious decision).
5. **Gate:** none yet — this is the baseline. Run `scripts/metric-logger.sh report` once now anyway so there's a zero-point to diff against later.
6. Add `spec` to `layers_committed:` in `brain/Features/<feature>.md`.
```

- [ ] **Step 1: Verify target text**

Confirm this exact string is present in `.claude/skills/driver/SKILL.md`:
```
3. Commit: `spec(<feature>): <one-line summary>`
4. **Gate:** none yet — this is the baseline. Run `scripts/metric-logger.sh report` once now anyway so there's a zero-point to diff against later.
5. Add `spec` to `layers_committed:` in `brain/Features/<feature>.md`.
```

- [ ] **Step 2: Apply the edit**

Replace the text above with:
```
3. Commit: `spec(<feature>): <one-line summary>`
4. Load `obsidian-integration`. Update `brain/Features/<feature>.md` to reflect the spec just written (the ticket was created in Step 1a of `spec-driven-development` — this updates it if anything changed). If the spec's **Design Decisions** section has content, create or update the relevant note in `brain/Decisions/` (one ADR per non-obvious decision).
5. **Gate:** none yet — this is the baseline. Run `scripts/metric-logger.sh report` once now anyway so there's a zero-point to diff against later.
6. Add `spec` to `layers_committed:` in `brain/Features/<feature>.md`.
```

- [ ] **Step 3: Verify the edit landed**

Read `.claude/skills/driver/SKILL.md` lines 41–52 and confirm step 4 is the brain update and step 5 is the gate.

- [ ] **Step 4: Commit**

```bash
cd /path/to/project
git add .claude/skills/driver/SKILL.md
git commit -m "feat(driver-brain-update-per-layer): brain update after spec layer"
```

---

### Task 2: Layer 2 (api) — add brain update sub-step

**Files:**
- Modify: `.claude/skills/driver/SKILL.md` (Layer 2 section)

Current Layer 2 step 4 combines the gate check and the `layers_committed` write in one step. We split it: brain update first, then gate + committed.

- [ ] **Step 1: Verify target text**

Confirm this exact string is present:
```
3. Do **not** commit per task here — that's `tdd-loop`'s own concern when run standalone. Under the driver, let all api tasks land, then make **one** commit for the layer: `feat(<feature>): api — <tasks summary>`.
4. **Gate before moving to app** — run the check in "Gates, summarized" below. On pass, add `api` to `layers_committed:`.
```

- [ ] **Step 2: Apply the edit**

Replace the text above with:
```
3. Do **not** commit per task here — that's `tdd-loop`'s own concern when run standalone. Under the driver, let all api tasks land, then make **one** commit for the layer: `feat(<feature>): api — <tasks summary>`.
4. Load `obsidian-integration`. Update brain folders based on what this layer touched:
   - Migrations or schema changes → update `brain/Database/` (table changes, new columns, index rationale)
   - New or changed endpoints, webhooks, or external service integrations → update `brain/APIs/`
   - If neither applies, skip this step.
5. **Gate before moving to app** — run the check in "Gates, summarized" below. On pass, add `api` to `layers_committed:`.
```

- [ ] **Step 3: Verify the edit landed**

Read the Layer 2 section and confirm step 4 is the brain update and step 5 is the gate.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/driver/SKILL.md
git commit -m "feat(driver-brain-update-per-layer): brain update after api layer"
```

---

### Task 3: Layer 3 (app) — add brain update sub-step

**Files:**
- Modify: `.claude/skills/driver/SKILL.md` (Layer 3 section)

Layer 3 is currently a single paragraph (no numbered list). We expand it to a numbered list that mirrors Layer 2's structure, adding the brain update before the gate.

- [ ] **Step 1: Verify target text**

Confirm this exact string is present:
```
### 3. Layer: app (skip if no UI/consumer tasks)

Same mechanics as **api**: parallelize across stacks if independent, run `tdd-loop` per task, one commit for the layer (`feat(<feature>): app — <tasks summary>`), same gate below before advancing. On pass, add `app` to `layers_committed:`.

If the spec touches UI and no mockup exists yet, run `spec-driven-development` Step 3 (mockup) first and fold its commit into this layer.
```

- [ ] **Step 2: Apply the edit**

Replace the text above with:
```
### 3. Layer: app (skip if no UI/consumer tasks)

1. If the spec touches UI and no mockup exists yet, run `spec-driven-development` Step 3 (mockup) first and fold its commit into this layer.
2. Apply the parallelization check: 2+ app tasks on different stacks → parallel agents in worktrees; same stack or dependent → sequential, same session.
3. For each task: load the matching `stacks/<stack>` skill, run `tdd-loop`, land on green.
4. One commit for the layer: `feat(<feature>): app — <tasks summary>`.
5. Load `obsidian-integration`. Update brain folders based on what this layer touched:
   - New services, data flows, or cross-component interactions → update `brain/Architecture/`
   - New patterns, conventions, or modules introduced → update `brain/Codebase/`
   - If neither applies, skip this step.
6. **Gate before moving to qa** — run the check in "Gates, summarized" below. On pass, add `app` to `layers_committed:`.
```

- [ ] **Step 3: Verify the edit landed**

Read the Layer 3 section and confirm it now has 6 numbered steps, with step 5 being the brain update.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/driver/SKILL.md
git commit -m "feat(driver-brain-update-per-layer): brain update after app layer"
```

---

### Task 4: Layer 4 (qa) — explicitly document brain update is skipped

**Files:**
- Modify: `.claude/skills/driver/SKILL.md` (Layer 4 section)

- [ ] **Step 1: Verify target text**

Confirm this exact string is present:
```
3. **Gate:** all specs green. A red spec after the healer's pass means stop and surface it — the driver does not paper over a failing test by narrowing scope.
4. Add `qa` to `layers_committed:`.
```

- [ ] **Step 2: Apply the edit**

Replace with:
```
3. **Gate:** all specs green. A red spec after the healer's pass means stop and surface it — the driver does not paper over a failing test by narrowing scope.
4. No brain update — tests do not generate domain knowledge. Add `qa` to `layers_committed:`.
```

- [ ] **Step 3: Verify the edit landed**

Read Layer 4 and confirm step 4 contains the "No brain update" note.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/driver/SKILL.md
git commit -m "feat(driver-brain-update-per-layer): document qa skips brain update"
```

---

### Task 5: Layer 5 (stats) — scope update to folders not yet covered

**Files:**
- Modify: `.claude/skills/driver/SKILL.md` (Layer 5 section)

Current Layer 5 step 2 says "plus any domain folder the feature touched". This needs to say "plus any domain folder **not already updated by a prior layer**" so it's explicit about its catch-all role.

- [ ] **Step 1: Verify target text**

Confirm this exact string is present:
```
2. Load `obsidian-integration` and update `brain/Features/<feature>.md` (status → `shipped`, tick tasks, wikilinks, `layers_committed:` → add `stats`) plus any domain folder the feature touched (`Architecture/`, `Codebase/`, `Database/`, `APIs/`, `Decisions/`).
```

- [ ] **Step 2: Apply the edit**

Replace with:
```
2. Load `obsidian-integration` and update `brain/Features/<feature>.md` (status → `shipped`, tick tasks, wikilinks, `layers_committed:` → add `stats`) plus any domain folder **not already updated by a prior layer** (`Architecture/`, `Codebase/`, `Database/`, `APIs/`, `Decisions/`). Earlier layers update folders incrementally as they land — stats is the catch-all for anything that slipped through or for features where a layer was skipped.
```

- [ ] **Step 3: Verify the edit landed**

Read Layer 5 step 2 and confirm it contains "not already updated by a prior layer".

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/driver/SKILL.md
git commit -m "feat(driver-brain-update-per-layer): stats layer scoped to catch-all role"
```

---

### Task 6: Update the layer summary table

**Files:**
- Modify: `.claude/skills/driver/SKILL.md` (The 5 layers table, line 23–29)

The summary table's Layer 5 currently says "Metrics, brain update, PR". Since brain updates now happen across all layers, the "Does" column needs updating.

- [ ] **Step 1: Verify target text**

Confirm this exact string is present:
```
| 5 | **stats** | Metrics, brain update, PR | `churn`, `obsidian-integration`, `/save` semantics | `chore(<feature>): stats —` |
```

- [ ] **Step 2: Apply the edit**

Replace with:
```
| 5 | **stats** | Metrics, final brain catch-all, PR | `churn`, `obsidian-integration`, `/save` semantics | `chore(<feature>): stats —` |
```

Also update the description for layers 1–3 in the same table to mention brain updates:

Verify this exact string:
```
| 1 | **spec** | Actors, use cases, stages/tasks, graphify context | `spec-driven-development` (Steps 1–2) | `spec(<feature>):` |
| 2 | **api** | Tasks tagged `rails`/`python` that define a contract (endpoints, schemas, jobs) | `tdd-loop` + `stacks/rails` or `stacks/python` | `feat(<feature>): api —` |
| 3 | **app** | Tasks tagged `react` (or UI-facing rails views) that consume the contract | `tdd-loop` + `stacks/react` | `feat(<feature>): app —` |
| 4 | **qa** | End-to-end coverage of the use cases | `e2e` (planner → generator → healer) | `test(<feature>): e2e —` |
```

Replace with:
```
| 1 | **spec** | Actors, use cases, stages/tasks, graphify context + brain/Features + brain/Decisions | `spec-driven-development` (Steps 1–2), `obsidian-integration` | `spec(<feature>):` |
| 2 | **api** | Backend contracts (endpoints, schemas, jobs) + brain/Database + brain/APIs | `tdd-loop` + `stacks/rails` or `stacks/python`, `obsidian-integration` | `feat(<feature>): api —` |
| 3 | **app** | UI/consumer tasks + brain/Architecture + brain/Codebase | `tdd-loop` + `stacks/react`, `obsidian-integration` | `feat(<feature>): app —` |
| 4 | **qa** | End-to-end coverage of the use cases (no brain update) | `e2e` (planner → generator → healer) | `test(<feature>): e2e —` |
```

- [ ] **Step 3: Verify the edit landed**

Read the table and confirm all 5 rows reflect the new brain update distribution.

- [ ] **Step 4: Final commit**

```bash
git add .claude/skills/driver/SKILL.md
git commit -m "feat(driver-brain-update-per-layer): update layer summary table"
```

---

## Verification

After all tasks complete, do a full read of `.claude/skills/driver/SKILL.md` and confirm:

- [ ] Layer 1 step 4 = brain update (Features + Decisions)
- [ ] Layer 2 step 4 = brain update (Database + APIs conditional)
- [ ] Layer 3 step 5 = brain update (Architecture + Codebase conditional)
- [ ] Layer 4 step 4 = explicit "No brain update" note
- [ ] Layer 5 step 2 = "not already updated by a prior layer"
- [ ] Summary table rows 1–5 reflect the new distribution
