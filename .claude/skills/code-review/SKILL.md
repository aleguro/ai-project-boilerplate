---
name: code-review
description: Code review for this monorepo's pull requests. Reads docs/review.md for project-specific guidelines, then appends findings to it.
---

# Code Review

## Before Reviewing

1. Read `docs/review.md` in full — especially Part 2 (learnings from past reviews)
2. Run `git diff origin/main...HEAD --stat` to understand scope and which stacks changed (`apps/rails-app`, `apps/react-app`, `services/python-service`, …)
3. Check the spec in `docs/superpowers/specs/` and the active plan in `docs/superpowers/plans/` for intended scope
4. Load the stack skill(s) for whatever changed (`stacks/rails`, `stacks/react`, `stacks/python`) — review against that stack's own conventions, not generic rules

## Review Checklist

### Spec Compliance
- [ ] All changed files were in the plan/spec scope
- [ ] Acceptance criteria from the spec (`docs/superpowers/specs/`) are met
- [ ] No features added beyond what was specced — unexplained extras are `spec_drift`
- [ ] No functions over 40 lines without test coverage (`ai_blob_score`)

### Architecture
- [ ] Controllers/routes stay thin — no business logic (see the relevant `stacks/*` skill for where logic belongs)
- [ ] Shared types/schemas live in one place — never duplicated across stacks
- [ ] No secrets hardcoded (check for API keys, passwords, tokens)
- [ ] New dependencies justified and minimal

### Code Quality
- [ ] Follows the loaded stack skill's conventions (naming, file layout, anti-patterns)
- [ ] Error paths handled
- [ ] No debug prints (`console.log`, `puts`, `print`) left in production code

### Tests
- [ ] New source files have test counterparts
- [ ] Tests assert behavior, not implementation details
- [ ] No tests that only test the mock
- [ ] One assertion per test where practical

## Hallucination Check

Flag any code that:
- Implements behavior not described in the spec
- Makes assumptions about data shape, auth, or permissions without schema/spec backing
- References APIs, models, or fields that don't exist elsewhere in the codebase (verify with `graphify query`)

## After Reviewing

Append findings to `docs/review.md` Part 2:

```markdown
## YYYY-MM-DD — <branch-name>
**Issues found:**
- ...

**Avoid:**
- ...

**Replicate:**
- ...
```

Use `git add docs/review.md && git commit -m "docs: code review learnings <branch>"`.
