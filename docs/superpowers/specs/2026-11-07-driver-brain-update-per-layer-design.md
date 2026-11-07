# Spec: driver — brain update per layer

**Date:** 2026-11-07
**Branch:** feature/driver-brain-update-per-layer
**Stack:** skills (markdown only)
**Ticket:** brain/Features/driver-brain-update-per-layer.md

---

## Context

The `driver` skill currently updates Obsidian only in Layer 5 (stats), at the end of a feature. If the driver is interrupted between layers, or if users want the brain to reflect work-in-progress, the brain stays stale until the feature ships.

---

## Actors

| Actor | Role |
|-------|------|
| Claude (driver) | Executes the layer sequence |
| Obsidian brain | Receives updates after each layer |

---

## Use Cases

### UC-01: Brain updated after spec layer
- **Actor:** Claude (driver)
- **Precondition:** Layer 1 (spec) commit landed
- **Main flow:**
  1. Driver loads `obsidian-integration`
  2. Driver updates `brain/Features/<feature>.md` (ticket created/updated)
  3. Driver scans spec's Design Decisions section → updates `brain/Decisions/` if non-obvious decisions exist
  4. Driver adds `spec` to `layers_committed:`
- **Postcondition:** Brain reflects spec state before Layer 2 starts

### UC-02: Brain updated after api layer
- **Actor:** Claude (driver)
- **Precondition:** Layer 2 (api) commit landed
- **Main flow:**
  1. Driver loads `obsidian-integration`
  2. If layer touched migrations → update `brain/Database/`
  3. If layer added/changed endpoints or external integrations → update `brain/APIs/`
  4. Driver adds `api` to `layers_committed:`
- **Postcondition:** Brain reflects api changes before Layer 3 starts

### UC-03: Brain updated after app layer
- **Actor:** Claude (driver)
- **Precondition:** Layer 3 (app) commit landed
- **Main flow:**
  1. Driver loads `obsidian-integration`
  2. If layer introduced new data flows or services → update `brain/Architecture/`
  3. If layer introduced new patterns or modules → update `brain/Codebase/`
  4. Driver adds `app` to `layers_committed:`
- **Postcondition:** Brain reflects app changes before Layer 4 starts

### UC-04: QA layer skips brain update
- **Actor:** Claude (driver)
- **Precondition:** Layer 4 (qa) commit landed
- **Main flow:**
  1. Driver adds `qa` to `layers_committed:` — no brain update needed
- **Postcondition:** No brain changes from test-only commits

### UC-05: Stats layer does final brain update
- **Actor:** Claude (driver)
- **Precondition:** Layers spec/api/app/qa committed
- **Main flow:**
  1. Driver loads `obsidian-integration`
  2. Updates any domain folder not yet covered by earlier layers
  3. Sets `status: shipped` in `brain/Features/<feature>.md`
  4. Generates session metrics → `brain/Metrics/`
  5. Commits brain + pushes PR
- **Postcondition:** Brain fully reflects the shipped feature

---

## Stages and Tasks

### Stage 1: Update driver skill

- [ ] **T1.1** — Add brain update sub-step to Layer 1 (spec) in `driver/SKILL.md` | Stack: skills | Size: S | Human: 0.5h
- [ ] **T1.2** — Add brain update sub-step to Layer 2 (api) in `driver/SKILL.md` | Stack: skills | Size: S | Human: 0.5h
- [ ] **T1.3** — Add brain update sub-step to Layer 3 (app) in `driver/SKILL.md` | Stack: skills | Size: S | Human: 0.5h
- [ ] **T1.4** — Explicitly document that Layer 4 (qa) skips brain update | Stack: skills | Size: XS | Human: 0.1h
- [ ] **T1.5** — Update Layer 5 (stats) to clarify it only covers what prior layers didn't | Stack: skills | Size: S | Human: 0.3h

---

## Layer → Brain Folder Mapping

| Layer | Brain folders | Condition |
|-------|--------------|-----------|
| spec | `Features/` (always), `Decisions/` | always; Decisions only if spec has design decisions |
| api | `Database/` | if migrations or schema changes |
| api | `APIs/` | if new/changed endpoints or external integrations |
| app | `Architecture/` | if new services or data flows |
| app | `Codebase/` | if new patterns or modules |
| qa | — | skipped |
| stats | any folder not yet updated + `Features/` → shipped + `Metrics/` | always |

---

## Acceptance Criteria

- [ ] After Layer 1 commits, `brain/Features/<feature>.md` exists and `brain/Decisions/` is updated if spec has decisions
- [ ] After Layer 2 commits, `brain/Database/` and/or `brain/APIs/` are updated if applicable
- [ ] After Layer 3 commits, `brain/Architecture/` and/or `brain/Codebase/` are updated if applicable
- [ ] Layer 4 (qa) makes no brain changes
- [ ] Layer 5 (stats) covers remaining folders and sets `status: shipped`
- [ ] A driver interrupted after Layer 2 leaves the brain in a consistent state reflecting spec + api work

---

## Design Decisions

- Brain updates use the existing `obsidian-integration` skill — no new tooling needed
- The mapping is conditional, not exhaustive — a layer with no relevant changes skips the update silently
- Layer 5 retains its catch-all role to avoid any folder being permanently skipped if a layer had nothing to update
