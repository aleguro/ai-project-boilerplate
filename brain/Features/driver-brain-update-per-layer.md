---
title: Driver — Brain Update Per Layer
tags: [feature, driver, obsidian, brain]
created: 2026-11-07
updated: 2026-11-07
status: draft
type: feature
spec: docs/superpowers/specs/2026-11-07-driver-brain-update-per-layer-design.md
branch: feature/driver-brain-update-per-layer
layers_committed: []
---

# Driver — Brain Update Per Layer

## Summary

The driver currently updates Obsidian only in Layer 5 (stats). This feature adds inline brain updates at the close of each layer so the vault reflects work-in-progress state, not just the final shipped state.

## Actors

- **Claude (driver)** — executes the layer sequence and triggers brain updates

## Acceptance criteria

- [ ] After Layer 1 commits, `brain/Features/<feature>.md` exists and `brain/Decisions/` updated if applicable
- [ ] After Layer 2 commits, `brain/Database/` and/or `brain/APIs/` updated if applicable
- [ ] After Layer 3 commits, `brain/Architecture/` and/or `brain/Codebase/` updated if applicable
- [ ] Layer 4 (qa) makes no brain changes
- [ ] Layer 5 (stats) covers remaining folders and sets `status: shipped`

## Tasks

### Stage 1: Update driver skill

- [ ] **T1.1** — Add brain update sub-step to Layer 1 (spec) | Stack: skills | Size: S | Human: 0.5h
- [ ] **T1.2** — Add brain update sub-step to Layer 2 (api) | Stack: skills | Size: S | Human: 0.5h
- [ ] **T1.3** — Add brain update sub-step to Layer 3 (app) | Stack: skills | Size: S | Human: 0.5h
- [ ] **T1.4** — Document that Layer 4 (qa) skips brain update | Stack: skills | Size: XS | Human: 0.1h
- [ ] **T1.5** — Update Layer 5 (stats) catch-all language | Stack: skills | Size: S | Human: 0.3h

## Decisions

_Wikilinks to ADRs in [[Decisions/]] created during this feature._

## Related

- [[Architecture/index]]
