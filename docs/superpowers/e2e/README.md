# E2E Testing — Setup & Conventions

This doc is the source of truth for the project's Playwright E2E harness. The three AI agents (`playwright-test-planner`, `playwright-test-generator`, `playwright-test-healer`) read it before every task.

## Prerequisites

### 1. Playwright MCP server

The agents use the `mcp__playwright-test__*` tools. Install the Playwright MCP server:

```bash
# Add a .mcp.json at the project root (NOT .claude/settings.json — that
# file doesn't accept an "mcpServers" key on every Claude Code host):
{
  "mcpServers": {
    "playwright-test": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--isolated"]
    }
  }
}
```

Or install globally:

```bash
npm install -g @playwright/mcp
```

### 2. Playwright in the project

```bash
cd tests/e2e
npm install
npx playwright install chromium
```

Set `video: 'on'` under `use` in `playwright.config.ts` — without it there's nothing for `scripts/e2e-to-gif.sh` to turn into evidence GIFs for the PR. `trace: 'retain-on-failure'` alone only keeps something when a test fails:

```ts
use: {
  baseURL: process.env.BASE_URL ?? 'http://localhost:5173',
  trace: 'retain-on-failure',
  video: 'on',
},
```

### 3. Test stack

The E2E suite runs against a local or CI stack. Set up `tests/e2e/.env.local`:

```bash
# tests/e2e/.env.local
BASE_URL=http://localhost:3000
API_URL=http://localhost:8080
ADMIN_EMAIL=admin@test.local
ADMIN_PASSWORD=<test-password>
```

Start the stack:
```bash
# adjust to your project's setup command
make dev
# or
docker compose up -d
```

### 4. Global setup

Bootstrap seeds the admin user and any global data:

```bash
cd tests/e2e
npx playwright test --project=setup
```

This is required once per fresh stack. CI runs it automatically.

## Running tests

```bash
# All tests
cd tests/e2e && npx playwright test

# One feature
npx playwright test tests/dashboards/

# One spec
npx playwright test -g "TC-01" --project=chromium

# Only previously failing
npx playwright test --last-failed --project=chromium

# With browser UI (debugging)
npx playwright test --headed --project=chromium
```

## Conventions

### Naming

- **TC-NN** prefix on every test title: `TC-01 searching by name writes the query to the URL`
- Spec files: `tests/e2e/tests/<feature>/<scope>.spec.ts` — no redundant feature prefix in the filename
- Driver files: `tests/e2e/drivers/<feature>.ts`

### Auth fixture

`authedPage` is the standard fixture — logs in as the seeded admin user once per worker (cached storage state). Import from `../../fixtures/auth`:

```ts
import { expect, test } from '../../fixtures/auth';

test('TC-01 ...', async ({ authedPage: page }) => { ... });
```

For API-driven operations inside drivers, get the token:
```ts
import { authToken } from '../helpers/common';

const token = await authToken(page);
await page.request.post('/api/resource', {
  headers: { Authorization: `Bearer ${token}` },
  data: { ... }
});
```

### Driver pattern

A driver encapsulates the feature's locators and actions. It is test-scoped and auto-cleans up via `dispose`.

```ts
// tests/e2e/drivers/settings.ts
import { driver, uniqueName as uid } from './kit';

export { uniqueName } from './kit';

export const test = driver(
  'settings',
  (page) => ({
    async open() { await page.goto('/settings/profile'); },
    nameInput: () => page.getByTestId('display-name-input'),
    async setDisplayName(name: string) { await this.nameInput().fill(name); },
    async save() {
      await Promise.all([
        page.waitForResponse((r) => r.url().includes('/api/users/') && r.request().method() === 'PATCH'),
        page.getByTestId('save-button').click(),
      ]);
    },
  }),
);

export { expect } from '@playwright/test';
```

### Self-contained state

- The bootstrap creates a fresh stack with **zero application data** (besides the global setup).
- Every test seeds its own data and cleans up after itself.
- Driver `dispose` handles cleanup automatically.
- Never assert exact counts on globally shared data — assert structure.

### Locator priority

1. `data-testid` — search with `grep -r 'data-testid=' apps/<frontend>/src/`
2. `getByRole('button', { name: 'Submit' })`
3. `getByLabel`, `getByPlaceholder`, `getByText`
4. CSS selectors — last resort

### Hard rules

| Rule | Why |
|------|-----|
| No `test.only` | CI uses `forbidOnly: true` |
| No `waitForTimeout(ms)` | Flaky; use `await expect(locator).toBe…()` |
| No `networkidle` | Flaky |
| No raw `page.*` in specs | Locators belong in drivers |
| Don't weaken assertions to fix red | Mark `test.fixme(...)` instead |

## Common gotchas

**Popovers outside the viewport:** `element.dispatchEvent('click')` bypasses coordinate checks when Playwright complains about "Element is outside of the viewport." Works for popover menu items where `force: true` isn't enough.

**Async mutations vs navigation:** Clicking a delete/submit button triggers an async mutation. Wait for the API response and dialog dismissal before navigating away:
```ts
await Promise.all([
  page.waitForResponse((r) => r.request().method() === 'DELETE' && r.url().includes('/api/items/')),
  page.getByTestId('delete-button').click(),
]);
await expect(dialog).not.toBeVisible();
```

**Zero-state hides controls:** With no seeded data, list controls may not render. Always seed at least one resource before driving list-page interactions.

**Sticky headers:** Rows below a sticky table header need `scrollIntoViewIfNeeded()` before clicking. Put this inside the driver action, not the spec.

## CI integration

Add to your CI pipeline (GitHub Actions example):

```yaml
- name: Run E2E tests
  run: |
    cd tests/e2e
    npx playwright test --project=chromium
  env:
    BASE_URL: ${{ env.APP_URL }}
    API_URL: ${{ env.API_URL }}
    ADMIN_EMAIL: ${{ secrets.TEST_ADMIN_EMAIL }}
    ADMIN_PASSWORD: ${{ secrets.TEST_ADMIN_PASSWORD }}
```

Artifacts on failure:
```yaml
- uses: actions/upload-artifact@v3
  if: failure()
  with:
    name: playwright-results
    path: tests/e2e/artifacts/
```

## Gitignore additions

```gitignore
# E2E scratch artifacts
tests/e2e/specs/
tests/e2e/artifacts/
tests/e2e/.env.local
tests/e2e/playwright-report/
tests/e2e/test-results/
```
