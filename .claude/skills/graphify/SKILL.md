---
name: graphify
description: Graphify end-to-end — how to generate the knowledge graph for any project and how to consume it as a model. Use before any codebase question, architecture decision, or feature planning.
---

# Graphify — End-to-End

## What is graphify

Graphify builds a semantic knowledge graph of the codebase: nodes are modules/classes/functions, edges are dependencies and call relationships. The model consumes it through targeted queries instead of reading raw files.

---

## 1. Generation — First Time (init)

Before using graphify in a project that has no `graphify-out/` yet:

```bash
cd <project-root>

# Find which Python has graphify installed
GPY=$(python3 -c "import graphify; import sys; print(sys.executable)" 2>/dev/null || echo "python3")

# Init — builds graph.json + wiki + GRAPH_REPORT.md
"$GPY" -m graphify init .

# Store the interpreter path for future use
mkdir -p graphify-out
echo "$GPY" > graphify-out/.graphify_python
```

> Ask the user before running `init` on a project — it indexes the whole codebase.

---

## 2. Generation — Keeping the Graph Fresh (update)

Run after any non-trivial code change (new file, renamed module, new dependency):

```bash
GPY=$(cat graphify-out/.graphify_python)
"$GPY" -m graphify update .
```

The `scripts/graphify-update.sh` script handles this automatically and is wired to the PostToolUse hook in `settings.json`.

---

## 3. Consumption — How Models Use the Graph

### Always start here

```bash
GPY=$(cat graphify-out/.graphify_python)
```

### Navigation flow (in order)

```
1. Read graphify-out/wiki/index.md    ← high-level map first (cheap)
2. query "<topic>"                    ← find relevant nodes
3. explain "<ClassName>"              ← deep-dive one node
4. path "<ModuleA>" "<ModuleB>"       ← trace a dependency chain
```

### Commands

```bash
# "Which files handle X?"
"$GPY" -m graphify query "<topic>"

# "What does Y do and what does it depend on?"
"$GPY" -m graphify explain "<ClassName or function>"

# "How does A talk to B?"
"$GPY" -m graphify path "<ModuleA>" "<ModuleB>"

# Full architecture review (large — use sparingly)
cat graphify-out/GRAPH_REPORT.md
```

### When to use each

| Question | Command |
|----------|---------|
| "Where is X implemented?" | `query` |
| "What does Y depend on?" | `explain` |
| "How does A reach B?" | `path` |
| "Full architecture review" | `GRAPH_REPORT.md` |

---

## 4. Monorepo Usage

Each sub-project has its own `graphify-out/`. Always `cd` into the sub-project first:

```bash
cd apps/rails-app
GPY=$(cat graphify-out/.graphify_python)
"$GPY" -m graphify query "authentication"
```

Do NOT run graphify from the monorepo root — it will index everything and produce noise.

---

## 5. Output Files Reference

| File | Contents |
|------|----------|
| `graphify-out/graph.json` | Raw graph — nodes + edges |
| `graphify-out/wiki/index.md` | Human-readable module index |
| `graphify-out/wiki/<Module>.md` | Per-module wiki page |
| `graphify-out/GRAPH_REPORT.md` | Full architecture report |
| `graphify-out/.graphify_python` | Python interpreter path |

---

## 6. Metric Logging

Every graphify call is picked up by the metric logger. Use `scripts/metric-logger.sh graphify "<command>:<args>"` after each call to track consumption.
