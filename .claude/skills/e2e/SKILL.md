---
name: e2e
description: Orchestrates the three-agent Playwright E2E workflow (planner → generator → healer). Load before any E2E-related request.
triggers:
  - /e2e
  - writing E2E tests
  - playwright tests
  - test coverage for a feature
---

# E2E Testing Workflow

This project uses a three-agent Playwright pipeline. Each agent is specialized and autonomous — they have restricted toolsets and isolated context.

## The agents

| Agent | Role | When to use |
|-------|------|-------------|
| `playwright-test-planner` | Reads source + explores the live UI → produces a structured TC-NN test plan | When a new feature ships or you need to audit coverage gaps |
| `playwright-test-generator` | Takes the plan → drives scenarios in a real browser → writes `.spec.ts` files | After the planner has produced a plan |
| `playwright-test-healer` | Debugs and fixes red specs without touching passing tests | When CI goes red or a spec breaks after a frontend change |

## Why agents instead of a skill?

Each agent has a **different toolset** and **different context needs**:

- The **planner** needs both browser exploration tools AND source code tools. It must navigate the live app to understand real UI behavior.
- The **generator** needs browser tools to drive scenarios + Write/Edit to produce code. It only needs the plan, not the full exploration history.
- The **healer** needs debug tools (`test_debug`, `test_run`, `generate_locator`) + browser inspection. It only needs the failing test + the source, not the planning history.

Running them as separate agents means each starts with a clean context, uses only the tools it needs, and can be spawned in parallel when independent features are being tested.

## Pipeline

```
Feature ships
     │
     ▼
playwright-test-planner
  ├── reads frontend source (Grep/Glob/Read)
  ├── navigates live app (mcp__playwright-test__browser_*)
  └── writes tests/e2e/specs/<feature>/<feature>-test-plan.md
     │
     ▼
playwright-test-generator
  ├── reads the plan
  ├── drives each scenario in a real browser
  ├── writes tests/e2e/tests/<feature>/*.spec.ts
  └── writes/extends tests/e2e/drivers/<feature>.ts
     │
     ▼
CI runs
     │
     ├── green → done
     └── red ──▶ playwright-test-healer
                   ├── runs failing tests
                   ├── debugs root cause
                   └── edits spec or driver (surgical only)
```

## How to invoke

```
# Plan tests for a feature
Agent(subagent_type: "playwright-test-planner",
      prompt: "Plan E2E tests for the <feature> page at <url>.
               Frontend source is in apps/<frontend>/src/pages/<Feature>/.")

# Generate specs from an existing plan
Agent(subagent_type: "playwright-test-generator",
      prompt: "Generate Playwright specs from the plan at
               tests/e2e/specs/<feature>/<feature>-test-plan.md")

# Heal failing specs
Agent(subagent_type: "playwright-test-healer",
      prompt: "tests/e2e/tests/<feature>/<spec>.spec.ts is failing, fix it.")
```

## Directory structure

```
tests/e2e/
  bootstrap/
    global.setup.ts         ← seeds global state (auth user, shared data)
  drivers/
    kit.ts                  ← driver() and seeded() factories
    <feature>.ts            ← per-feature locators + actions + dispose
  fixtures/
    auth.ts                 ← authedPage fixture (login once per worker)
    <domain>/               ← domain-specific extended fixtures
  helpers/
    auth.ts                 ← newAdminContext(browser)
    common.ts               ← authToken, watchConsole, seederUrl
  specs/                    ← gitignored scratch: plans + checklists
    <feature>/
      <feature>-test-plan.md
      checklists/
        <feature>-functional-checklist.md
  testdata/                 ← static payloads
  tests/
    <feature>/
      *.spec.ts
  playwright.config.ts
  tsconfig.json
```

## Rules

- `tests/e2e/specs/` is **gitignored** — plans are scratch artifacts, not documentation.
- `tests/e2e/tests/` is **committed** — specs are the source of truth.
- Test titles must follow `TC-NN <short description>` convention.
- Never `test.only` — CI runs with `forbidOnly: true`.
- Never `page.waitForTimeout(ms)` — always use `await expect(locator).toBe…()`.
- Self-contained state: each test seeds and cleans up its own data.
- Locator priority: `data-testid` > ARIA role > label/placeholder/text > CSS.

## Setup

See `docs/superpowers/e2e/README.md` for: Playwright MCP installation, test stack setup, environment variables, and first-run checklist.
