---
name: stack-react
description: React/TypeScript conventions for this monorepo. Load when working in any frontend app directory with a package.json. Covers component patterns, state, test runner, and anti-patterns.
---

# Stack — React / TypeScript

## When this skill applies

Load this skill whenever you are working in a directory that contains a `package.json` with `"react"` as a dependency.

---

## Project Conventions

### Component Rules
- **Signals over useState** — use `@preact/signals-react` or `zustand` for shared state; `useState` only for purely local UI state (open/closed toggle)
- **Named exports only** — no default exports on components
- **One component per file** — co-locate its styles and tests in the same directory
- **Props interface above the component**, named `<ComponentName>Props`

### File Layout
```
src/
  components/
    Button/
      Button.tsx
      Button.test.tsx
      Button.module.css
  features/
    auth/
      AuthForm.tsx
      authStore.ts
      auth.test.ts
  hooks/
  lib/           ← pure utilities, no React
  types/
```

---

## Test Runner

```bash
npm test                                  # watch mode
npm test -- --run                         # single pass (CI)
npm test -- --coverage                    # with coverage report
```

Minimum coverage: **75%** on `src/features/` and `src/components/`.

---

## Linting

```bash
npm run lint                              # ESLint
npm run typecheck                         # tsc --noEmit
```

---

## TDD Loop for React

1. Write a `*.test.tsx` with `@testing-library/react` — render + assert behavior
2. Run → red (component doesn't exist yet)
3. Create the component skeleton
4. Implement until green
5. Add edge-case tests (empty state, loading, error)
6. Refactor — extract hooks, memoize if needed

---

## Anti-Patterns — Never Do

- `any` type without a `// eslint-disable` comment explaining why
- `useEffect` for data fetching → use React Query or SWR
- Inline styles → use CSS modules or Tailwind classes
- Props drilling beyond 2 levels → lift to a store
- `console.log` in production code

---

## Graphify for React

```bash
cd apps/react-app
GPY=$(cat graphify-out/.graphify_python)
"$GPY" -m graphify query "authentication flow"
"$GPY" -m graphify explain "AuthStore"
```
