---
name: stack-python
description: Python conventions for this monorepo. Load when working in any directory with a pyproject.toml or requirements.txt. Covers patterns, test runner, linting, and anti-patterns.
---

# Stack — Python

## When this skill applies

Load this skill whenever you are working in a directory that contains a `pyproject.toml`, `requirements.txt`, or `setup.py`.

---

## Project Conventions

### Architecture
- **Typed everywhere** — `from __future__ import annotations`, full type hints, `mypy` clean
- **Pydantic for data models** — no raw dicts passed between layers
- **Dependency injection over globals** — pass clients/config as constructor args
- **No side effects at import time** — lazy initialization only

### File Layout
```
src/
  <package>/
    __init__.py
    domain/        ← pure Python, no I/O
    services/      ← orchestrate domain + infra
    infra/         ← DB, HTTP, queue clients
    api/           ← FastAPI routers (if applicable)
tests/
  unit/            ← domain tests, no I/O
  integration/     ← services + real infra (docker)
  conftest.py
```

---

## Test Runner

```bash
pytest                                    # full suite
pytest tests/unit/                        # unit only
pytest tests/integration/                 # integration only
pytest --cov=src --cov-report=term-missing
```

Minimum coverage: **80%** on `src/<package>/domain/` and `src/<package>/services/`.

---

## Linting

```bash
ruff check . --fix                        # linting + auto-fix
mypy src/                                 # type checking
```

---

## TDD Loop for Python

1. Write `tests/unit/test_<feature>.py` — test the domain function/class
2. Run → red
3. Implement the domain logic
4. Run → green
5. Add integration test in `tests/integration/` if it touches I/O
6. Refactor — extract helpers, add edge cases

---

## Anti-Patterns — Never Do

- Mutable default arguments (`def f(x=[])`)
- Catching bare `Exception` without re-raising or logging
- `print()` in production → use `logging`
- Business logic in API routers
- Importing from `infra/` inside `domain/`

---

## Graphify for Python

```bash
cd services/python-service
GPY=$(cat graphify-out/.graphify_python)
"$GPY" -m graphify query "data pipeline"
"$GPY" -m graphify explain "PipelineService"
```
