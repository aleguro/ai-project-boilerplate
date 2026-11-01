# Code Review Guidelines

## Part 1: Guidelines

### Architecture Rules

- Routes delegate to services — no business logic in route handlers
- Services are pure functions — no framework imports
- Shared types live in a shared module — never duplicated across packages
- DB queries only in services, never in routes or middleware

### Spec Compliance

A change is only valid if it was in the plan. Files touched outside plan scope must be
explained in the PR's "Spec Drift" section. Unexplained drift = hallucination risk.

### What Counts as a Hallucination Here

- Implementing behavior not described in the feature spec
- Adding features "because they seemed useful" without a spec backing them
- Making assumptions about auth, permissions, or data ownership without explicit spec

### Naming Conventions

- Files: kebab-case (`patch-engine.ts`, not `patchEngine.ts`)
- Classes: PascalCase
- Functions/variables: camelCase
- Test files: `<name>.test.<ext>` in the same directory as the source

### Tests

- Tests assert observable behavior, not internal state
- Mock only external boundaries (DB, HTTP, external APIs) — not internal services
- One assertion per test where practical
- Test descriptions: `it('should <behavior> when <condition>')`

---

## Part 2: Learnings

<!-- Code review findings are appended here by the code-review skill -->
<!-- Format: ## YYYY-MM-DD — <branch> -->
