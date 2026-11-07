#!/usr/bin/env bash
# create-pr.sh — generates a metrics-enriched PR via gh pr create (or updates body if PR exists)
# Called by push-pr.sh (the `git push-pr` alias) after a branch push.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
BRANCH="$(git branch --show-current)"
BRANCH_SLUG="$(echo "$BRANCH" | tr '/' '-')"
METRICS_FILE="/tmp/claude-metrics-${BRANCH_SLUG}.jsonl"
BASELINE_FILE="${REPO_ROOT}/docs/metrics/baseline.json"
DESIGNS_DIR="${REPO_ROOT}/docs/designs/${BRANCH_SLUG}"

# ── Read session report (don't re-run — that would overwrite with empty data) ───
# The driver's stats layer already ran `metric-logger.sh report` and saved it.
# Only generate a fresh report if none exists yet (e.g. first push before /save).
SESSION_REPORT=$(ls "${REPO_ROOT}/docs/metrics/session-"*"-${BRANCH_SLUG}.json" 2>/dev/null | sort | tail -1 || echo "")
if [ -z "$SESSION_REPORT" ]; then
  "${REPO_ROOT}/scripts/metric-logger.sh" report 2>/dev/null || true
  SESSION_REPORT=$(ls "${REPO_ROOT}/docs/metrics/session-"*"-${BRANCH_SLUG}.json" 2>/dev/null | sort | tail -1 || echo "")
fi

_report_val() {
  local key="$1" default="${2:-0}"
  if [ -n "$SESSION_REPORT" ] && [ -f "$SESSION_REPORT" ]; then
    python3 -c "
import json
d = json.load(open('${SESSION_REPORT}'))
val = d
for k in '${key}'.split('.'):
    val = val.get(k, '${default}') if isinstance(val, dict) else '${default}'
print(val)
" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

TOTAL_CALLS=$(wc -l < "$METRICS_FILE" 2>/dev/null | tr -d ' ' || echo 0)
SESSION_MINUTES=$(_report_val session_minutes "n/a")
GRAPHIFY_COUNT=$(_report_val graphify_calls)
BRAIN_READS=$(_report_val brain_docs_read)
BRAIN_WRITES=$(_report_val brain_docs_written)
TEST_RUNS=$(_report_val test_runs)
TASKS_DONE=$(_report_val tasks_completed)
TASKS_TOTAL_VAL=$(_report_val tasks_total)
AI_BLOB=$(_report_val ai_blob_score)
COST_USD=$(_report_val "cost.total_usd" "0")
COST_SOURCE=$(_report_val "cost.source" "unknown")

# Test results: build a markdown table from test_results dict in the report
TEST_EVIDENCE=""
if [ -n "$SESSION_REPORT" ] && [ -f "$SESSION_REPORT" ]; then
  TEST_EVIDENCE=$(python3 -c "
import json
d = json.load(open('${SESSION_REPORT}'))
results = d.get('test_results', {})
if not results:
    print('_No test results recorded — run scripts/metric-logger.sh testresult <suite> \"<summary>\" after each suite_')
else:
    print('| Suite | Result |')
    print('|-------|--------|')
    for suite, summary in results.items():
        print(f'| {suite} | {summary} |')
" 2>/dev/null || echo "_test results unavailable_")
fi

# Graphify query list from metrics file
GRAPHIFY_QUERIES=""
if [ -f "$METRICS_FILE" ]; then
  GRAPHIFY_QUERIES=$(grep '"type": "graphify"' "$METRICS_FILE" 2>/dev/null \
    | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line)
        call = d.get('call', '')
        if call:
            print('  - ' + call)
    except Exception:
        pass
" 2>/dev/null || echo "")
fi

# ── Baseline drift ──────────────────────────────────────────────────────────────
AVG=$(python3 -c "
import json
try:
    d = json.load(open('${BASELINE_FILE}'))
    print(d.get('avg_tool_calls', 0))
except Exception:
    print(0)
" 2>/dev/null || echo 0)

if python3 -c "exit(0 if int(${AVG}) > 0 else 1)" 2>/dev/null; then
  DRIFT=$(python3 -c "print(round((${TOTAL_CALLS} - ${AVG}) / ${AVG} * 100, 1))")
  DRIFT_STR="${DRIFT}% vs baseline avg ${AVG} calls"
else
  DRIFT_STR="no baseline yet (first PR)"
fi

# ── Spec drift ──────────────────────────────────────────────────────────────────
# Spec files are named YYYY-MM-DD-<feature>.md — strip common prefixes from branch
FEATURE_SLUG=$(echo "$BRANCH_SLUG" | sed 's/^feature-//; s/^bugfix-//; s/^chore-//; s/^fix-//')
SPEC_FILE=$(ls "${REPO_ROOT}/docs/superpowers/specs/"*"${FEATURE_SLUG}"* 2>/dev/null | head -1 || echo "")
TOUCHED_FILES=$(git diff --name-only "origin/main...HEAD" 2>/dev/null | sort -u || echo "")
OUTSIDE_SCOPE="(no spec file found)"

if [ -n "$SPEC_FILE" ] && [ -n "$TOUCHED_FILES" ]; then
  SPEC_TASKS=$(grep -oE 'Stack: (rails|react|python)' "$SPEC_FILE" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
  OUTSIDE_SCOPE="$(echo "$TOUCHED_FILES" | wc -l | tr -d ' ') files changed — compare against spec tasks (${SPEC_TASKS} task(s) defined)"
fi

# ── Test coverage delta ─────────────────────────────────────────────────────────
NEW_SOURCE=$(git diff --name-only --diff-filter=A "origin/main...HEAD" 2>/dev/null \
  | grep -vE "(test|spec|\.md$|\.json$|\.sh$|\.yml$|\.yaml$|Dockerfile|\.env|\.lock$|\.sample$)" \
  | grep -vE "^(brain/|docs/|infra/|\.claude/)" \
  | grep -vE "/(bin|config|db|public|assets|\.kamal)/" \
  | grep -vE "\.(png|svg|gif|mov|mp4|webm|ico|woff|woff2|ttf|eot|css)$" \
  | grep -vE "(Gemfile|Rakefile|index\.[jt]sx?|index\.html|nginx\.conf|vite\.config\.[jt]s|main\.[jt]sx?|application_[a-z]+\.[a-z]+)$" \
  || echo "")

UNTESTED=""
for f in $NEW_SOURCE; do
  [ -z "$f" ] && continue
  base=$(basename "$f" | sed 's/\.[^.]*$//')
  [ -z "$base" ] && continue
  # Strip Rails/Python suffixes so users_controller → users, welcome_job → welcome
  short=$(echo "$base" | sed 's/_controller$//; s/_job$//; s/_serializer$//; s/_service$//; s/_helper$//')
  [ -z "$short" ] && short="$base"
  if ! git diff --name-only "origin/main...HEAD" 2>/dev/null \
    | grep -qiE "(test|spec).*${base}|${base}.*(test|spec)|${short}.*(test|spec)|(test|spec).*${short}" 2>/dev/null; then
    UNTESTED="${UNTESTED}\n- ${f}"
  fi
done
[ -z "$UNTESTED" ] && UNTESTED="none"

# ── Commits summary ─────────────────────────────────────────────────────────────
COMMIT_SUMMARY=$(git log --oneline "origin/main...HEAD" 2>/dev/null | head -10 | sed 's/^/- /' || echo "- (no commits)")

# ── UI designs ──────────────────────────────────────────────────────────────────
DESIGNS_SECTION=""
if [ -d "$DESIGNS_DIR" ]; then
  DESIGN_FILES=$(find "$DESIGNS_DIR" -name "*.png" 2>/dev/null || echo "")
  if [ -n "$DESIGN_FILES" ]; then
    DESIGNS_SECTION="## UI Designs
| Screen | Mockup |
|--------|--------|"
    for img in $DESIGN_FILES; do
      name=$(basename "$img" .png)
      rel_path="docs/designs/${BRANCH_SLUG}/$(basename "$img")"
      DESIGNS_SECTION="${DESIGNS_SECTION}
| ${name} | ![${name}](${rel_path}) |"
    done
    DESIGNS_SECTION="${DESIGNS_SECTION}
"
  fi
fi

# ── PR title from branch ────────────────────────────────────────────────────────
PR_TITLE=$(echo "$BRANCH" | sed 's|.*/||' | sed 's/-/ /g' | \
  python3 -c "import sys; print(sys.stdin.read().strip().title())")

# ── Build body ──────────────────────────────────────────────────────────────────
PR_BODY="$(cat <<BODY
## Summary
${COMMIT_SUMMARY}

## Metrics

| Metric | Value |
|--------|-------|
| Session time | ${SESSION_MINUTES} min |
| Session tool calls | ${TOTAL_CALLS} |
| Token drift | ${DRIFT_STR} |
| Tasks completed | ${TASKS_DONE} / ${TASKS_TOTAL_VAL} |
| Test runs | ${TEST_RUNS} |
| AI blob score | ${AI_BLOB} / 20 max |
| Session cost (\`${COST_SOURCE}\`) | \$${COST_USD} |

## Graphify Usage (${GRAPHIFY_COUNT} queries)
${GRAPHIFY_QUERIES:-  _none — run graphify query before next feature_}

## Obsidian / Brain
- Docs read: ${BRAIN_READS}
- Docs written: ${BRAIN_WRITES}

## Test Evidence
${TEST_EVIDENCE}

## Spec Drift
${OUTSIDE_SCOPE}

## Test Coverage Delta
New files without tests:
$(printf '%b' "$UNTESTED")

${DESIGNS_SECTION}---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"

# ── Create or update PR ─────────────────────────────────────────────────────────
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")"
EXISTING_PR=$(gh pr view "$BRANCH" --json number -q .number 2>/dev/null || echo "")

if [ -n "$EXISTING_PR" ]; then
  # PR exists — update body via REST API (gh pr edit has a known GraphQL bug)
  gh api "repos/${REPO}/pulls/${EXISTING_PR}" -X PATCH -f body="$PR_BODY" > /dev/null
  echo "PR #${EXISTING_PR} body updated: https://github.com/${REPO}/pull/${EXISTING_PR}"
else
  gh pr create --title "$PR_TITLE" --body "$PR_BODY"
fi

# ── Update baseline ─────────────────────────────────────────────────────────────
python3 << PYEOF
import json
path = "${BASELINE_FILE}"
try:
    d = json.load(open(path))
except Exception:
    d = {"avg_tool_calls": 0, "sample_count": 0, "samples": []}

samples = d.get("samples", [])
samples.append(${TOTAL_CALLS})
samples = samples[-5:]
avg = round(sum(samples) / len(samples), 1)
d["avg_tool_calls"] = avg
d["sample_count"] = len(samples)
d["samples"] = samples
json.dump(d, open(path, "w"), indent=2)
print(f"Baseline updated: avg={avg} over {len(samples)} samples")
PYEOF

# ── Clean up metrics file ───────────────────────────────────────────────────────
rm -f "$METRICS_FILE"
