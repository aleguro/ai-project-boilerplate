#!/usr/bin/env bash
# create-pr.sh — generates a metrics-enriched PR via gh pr create
# Called by pr-trigger.sh after a branch push.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
BRANCH="$(git branch --show-current)"
BRANCH_SLUG="$(echo "$BRANCH" | tr '/' '-')"
METRICS_FILE="/tmp/claude-metrics-${BRANCH_SLUG}.jsonl"
BASELINE_FILE="${REPO_ROOT}/docs/metrics/baseline.json"
DESIGNS_DIR="${REPO_ROOT}/docs/designs/${BRANCH_SLUG}"

# ── Metric counts ──────────────────────────────────────────────────────────────
count_type() {
  local type="$1"
  if [ -f "$METRICS_FILE" ]; then
    grep -c "\"type\":\"${type}\"" "$METRICS_FILE" || echo 0
  else
    echo 0
  fi
}

TOTAL_CALLS=$(wc -l < "$METRICS_FILE" 2>/dev/null || echo 0)
GRAPHIFY_COUNT=$(count_type "graphify_request")
OBSIDIAN_COUNT=$(count_type "obsidian_request")
READ_COUNT=$(count_type "read")
BASH_COUNT=$(count_type "bash")

GRAPHIFY_QUERIES=""
if [ -f "$METRICS_FILE" ]; then
  GRAPHIFY_QUERIES=$(grep '"type":"graphify_request"' "$METRICS_FILE" \
    | python3 -c "import sys,json; [print('- ' + json.loads(l).get('cmd','')) for l in sys.stdin]" 2>/dev/null || echo "")
fi

# ── Baseline drift ─────────────────────────────────────────────────────────────
AVG=$(python3 -c "
import json
try:
    d = json.load(open('${BASELINE_FILE}'))
    print(d.get('avg_tool_calls', 0))
except:
    print(0)
")

if [ "$AVG" -gt 0 ] 2>/dev/null; then
  DRIFT=$(python3 -c "print(round((${TOTAL_CALLS} - ${AVG}) / ${AVG} * 100, 1))")
  DRIFT_STR="+${DRIFT}% vs baseline avg ${AVG}"
else
  DRIFT_STR="no baseline yet (first PR)"
fi

# ── Spec drift ─────────────────────────────────────────────────────────────────
PLAN_FILES=$(grep -rh "^\- \`" "${REPO_ROOT}"/*/docs/superpowers/plans/ \
  "${REPO_ROOT}"/docs/superpowers/plans/ 2>/dev/null \
  | grep "/" | sed "s/.*\`\(.*\)\`.*/\1/" | sort -u || echo "")

TOUCHED_FILES=$(git diff --name-only "origin/main...HEAD" 2>/dev/null | sort -u || echo "")

if [ -n "$PLAN_FILES" ] && [ -n "$TOUCHED_FILES" ]; then
  OUTSIDE_SCOPE=$(comm -13 \
    <(echo "$PLAN_FILES") \
    <(echo "$TOUCHED_FILES") || echo "")
else
  OUTSIDE_SCOPE="(could not determine — no plan files or no diff)"
fi

[ -z "$OUTSIDE_SCOPE" ] && OUTSIDE_SCOPE="none"

# ── Test coverage delta ────────────────────────────────────────────────────────
NEW_SOURCE=$(git diff --name-only --diff-filter=A "origin/main...HEAD" 2>/dev/null \
  | grep -vE "(test|spec|\.md$|\.json$|\.sh$)" || echo "")

UNTESTED=""
for f in $NEW_SOURCE; do
  basename_no_ext=$(basename "$f" | sed 's/\.[^.]*$//')
  if ! git diff --name-only "origin/main...HEAD" 2>/dev/null \
    | grep -qE "(test|spec).*${basename_no_ext}|${basename_no_ext}.*(test|spec)"; then
    UNTESTED="${UNTESTED}\n- ${f}"
  fi
done
[ -z "$UNTESTED" ] && UNTESTED="none"

# ── Summary from commits ────────────────────────────────────────────────────────
COMMIT_SUMMARY=$(git log --oneline "origin/main...HEAD" 2>/dev/null | head -10 | sed 's/^/- /' || echo "- (no commits)")

# ── UI Designs ────────────────────────────────────────────────────────────────
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
  fi
fi

# ── Unverified assumptions warning ────────────────────────────────────────────
ASSUMPTIONS_PLACEHOLDER="- [ ] (fill in before merge)"

# ── PR title from branch ───────────────────────────────────────────────────────
PR_TITLE=$(echo "$BRANCH" | sed 's|.*/||' | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')

# ── Create PR ─────────────────────────────────────────────────────────────────
gh pr create \
  --title "$PR_TITLE" \
  --body "$(cat <<BODY
## Summary
${COMMIT_SUMMARY}

## Token Consumption Drift
- Session tool calls: ${TOTAL_CALLS} (reads: ${READ_COUNT}, bash: ${BASH_COUNT})
- Drift: ${DRIFT_STR}

## Graphify Requests
- Count: ${GRAPHIFY_COUNT}
${GRAPHIFY_QUERIES}

## Obsidian Requests
- Count: ${OBSIDIAN_COUNT}

## Spec Drift
Outside-scope files touched:
${OUTSIDE_SCOPE}

## Test Coverage Delta
New files without tests:
$(printf '%b' "$UNTESTED")

${DESIGNS_SECTION}

## Unverified Assumptions
<!-- Claude MUST populate this section before merging -->
${ASSUMPTIONS_PLACEHOLDER}

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"

# ── Update baseline ────────────────────────────────────────────────────────────
python3 << PYEOF
import json, os
path = "${BASELINE_FILE}"
try:
    d = json.load(open(path))
except:
    d = {"avg_tool_calls": 0, "sample_count": 0, "samples": []}

samples = d.get("samples", [])
samples.append(${TOTAL_CALLS})
samples = samples[-5:]  # keep last 5
avg = round(sum(samples) / len(samples), 1)
d["avg_tool_calls"] = avg
d["sample_count"] = len(samples)
d["samples"] = samples
json.dump(d, open(path, "w"), indent=2)
print(f"Baseline updated: avg={avg} over {len(samples)} samples")
PYEOF

# ── Clean up metrics file ──────────────────────────────────────────────────────
rm -f "$METRICS_FILE"
