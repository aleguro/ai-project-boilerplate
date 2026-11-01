---
name: stack-rails
description: Rails-specific conventions for this monorepo. Load when working in any Rails app directory. Covers patterns, test runner, linting, and anti-patterns to avoid.
---

# Stack — Ruby on Rails

## When this skill applies

Load this skill whenever you are working in a directory that contains a `Gemfile` or `config/application.rb`.

---

## Project Conventions

### Architecture
- **Service objects** → use ODSL (`gem "odsl"`) for any multi-step business logic
- **Controllers** → thin: validate params, call one service, render. No business logic.
- **Models** → validations + scopes + associations only. No service logic.
- **Jobs** → delegate to a service via `ServiceClass.new(...).run_in_background(:method)`

### File Layout
```
app/
  controllers/       ← thin, REST only
  models/            ← AR models
  services/          ← ODSL service objects
  jobs/              ← ActiveJob wrappers
  serializers/       ← JSON serialization
spec/
  requests/          ← integration tests (primary)
  models/            ← unit tests for validations/scopes
  services/          ← unit tests for service objects
```

---

## Test Runner

```bash
bundle exec rspec                         # full suite
bundle exec rspec spec/services/          # services only
bundle exec rspec spec/requests/          # integration only
bundle exec rspec --format progress       # CI-friendly output
```

Minimum coverage: **80%** on `app/services/` and `app/controllers/`.

---

## Linting

```bash
bundle exec rubocop -A                    # auto-fix
bundle exec rubocop --format json > docs/metrics/rubocop.json
```

---

## TDD Loop for Rails

1. Write request spec first (happy path + one sad path)
2. Run → red
3. Add controller route + controller action (stub)
4. Add service skeleton
5. Implement service step by step until green
6. Refactor — extract private methods, add edge-case specs

---

## Anti-Patterns — Never Do

- `render json: @model.as_json` → use a serializer
- Business logic in controller actions
- Raw SQL outside of named scopes
- `rescue Exception` → rescue specific errors only
- `before_action` chains longer than 2 levels deep

---

## Graphify for Rails

```bash
cd apps/rails-app
GPY=$(cat graphify-out/.graphify_python)
"$GPY" -m graphify query "service objects"
"$GPY" -m graphify explain "ApplicationController"
```
