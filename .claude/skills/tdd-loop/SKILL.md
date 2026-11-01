---
name: tdd-loop
description: TDD loop for one spec task. Red → green → refactor until the task has full coverage. Load after spec-driven-development and the matching stack skill.
---

# TDD Loop

## Prerequisites

Before starting this loop:
- The task's spec is written (`docs/superpowers/specs/YYYY-MM-DD-<feature>.md`)
- Graphify has been consulted (context on existing code is clear)
- The stack skill is loaded (`stack-rails` / `stack-react` / `stack-python`)

---

## The Loop — Per Task

Repeat for each spec task `Txx` until all are green.

### Phase 1 — RED: write the test first

```
1. Read the spec task (main flow + alternative flows of the matching use case)
2. Create the test file: spec/services/test_<feature>_spec.rb (rails)
                          src/<feature>/<feature>.test.tsx (react)
                          tests/unit/test_<feature>.py (python)
3. Write ONE test for the main flow → it must fail
4. Run the suite → confirm the test is red
5. Do NOT write production code yet
```

### Phase 2 — GREEN: minimum to pass

```
6. Write the minimum production code to make the test pass
   → Don't anticipate the next test
   → Don't add logic the spec doesn't ask for
7. Run the suite → confirm green
8. Add a test for the use case's first alternative flow → red
9. Extend the code to pass it → green
10. Repeat for each alternative flow of the use case
```

### Phase 3 — REFACTOR: clean up without breaking

```
11. With all tests green:
    → Extract private methods if a public method exceeds 15 lines
    → Remove duplication between tests (factories, helpers)
    → Run the suite → still green
12. Run AI blob analysis:
    → no new function should exceed 40 lines
    → if it does: extract until it's ≤ 40 lines
```

### Phase 4 — COMMIT

```
13. git add -p    ← review each hunk before staging
14. git commit -m "feat(Txx): <task description>"
15. Mark the task [x] in the spec
16. Update metrics: scripts/metric-logger.sh task Txx green
```

---

## Signs the loop is off track

| Sign | What to do |
|------|-----------|
| The test is hard to write | The design is coupled — refactor first |
| The implementation needs data the spec doesn't mention | Go back to the spec, complete it |
| The test mocks more than 2 collaborators | Extract into a smaller service |
| Green without having written tests | Stop — those tests aren't testing anything |
| More than 3 loops without green | Split the task into smaller sub-tasks |

---

## Exit checklist per task

- [ ] Main flow test green
- [ ] Tests for all alternative flows of the use case green
- [ ] No functions > 40 lines
- [ ] No over-specified mocks
- [ ] Commit made with message `feat(Txx): ...`
- [ ] Task marked `[x]` in the spec
- [ ] `scripts/metric-logger.sh task Txx green` run

---

## When all tasks of a stage are done

```bash
# Run the full suite (not just the new tests)
<test-runner>

# Validate coverage
<test-runner-coverage>

# Stage metrics report
scripts/metric-logger.sh report
```

If coverage < the stack's minimum → add tests until it's reached before opening the PR.
