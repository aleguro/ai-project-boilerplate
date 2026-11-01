---
title: Features
tags: [index, features, tickets]
created: 2026-11-01
updated: 2026-11-01
status: active
type: index
---

# Features

One note per feature. Each note is a ticket that tracks the feature from idea to shipped.

## Status lifecycle

`draft` → `ready` → `in-progress` → `shipped` → `archived`

## Index

_Add a wikilink per feature as they are created._

## Template

Copy this template when creating a new feature note:

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

One paragraph describing what this feature does and why it matters.

## Actors

- **<Actor>** — <role>

## Acceptance criteria

- [ ] <criterion 1>
- [ ] <criterion 2>

## Tasks

_Populated from the spec stages._

### Stage 1 — <name>
- [ ] T1.1 — <description> | Stack: <stack> | Size: S/M/L | Human: Xh
- [ ] T1.2 — <description> | Stack: <stack> | Size: S/M/L | Human: Xh

### Stage 2 — <name>
- [ ] T2.1 — ... | Human: Xh

## Decisions

_Wikilinks to ADRs created during implementation._

## Related

_Wikilinks to Architecture/, Codebase/, Database/ notes touched by this feature._
```
