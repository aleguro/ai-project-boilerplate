#!/usr/bin/env bash
# metric-logger.sh — session metrics for AI-assisted development
#
# Usage (hook mode — stdin JSON from Claude):
#   echo '{"tool_name":"Bash","tool_input":{"command":"graphify query auth"}}' | scripts/metric-logger.sh
#
# Usage (explicit mode):
#   scripts/metric-logger.sh graphify "query:authentication"
#   scripts/metric-logger.sh task T1.1 green 4h                      # human estimate from spec (e.g. 4h, 1.5h)
#   scripts/metric-logger.sh cost opus 5000 2000                      # input_tokens output_tokens
#   scripts/metric-logger.sh cost sonnet 12000 4000
#   scripts/metric-logger.sh cost haiku 3000 800
#   scripts/metric-logger.sh testresult rspec "9 examples, 0 failures, 1 pending"
#   scripts/metric-logger.sh testresult vitest "2 passed (2)"
#   scripts/metric-logger.sh testresult playwright "3 passed (1.1s)"
#   scripts/metric-logger.sh report
#   scripts/metric-logger.sh feature-report <feature-name>            # saves docs/metrics/features/<feature>.json

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel 2>/dev/null || pwd)"
BRANCH="$(git -C "${REPO_ROOT}" branch --show-current 2>/dev/null | tr '/' '-')"
BRANCH="${BRANCH:-unknown}"
METRICS_FILE="/tmp/claude-metrics-${BRANCH}.jsonl"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Appends one JSON event line. Builds the object in Python so a value
# containing a `"` (a path, a shell command) can't produce invalid JSON
# that _report()/_feature_report() would then silently drop.
# Usage: _emit <type> [key=value ...]
_emit() {
  local type="$1"; shift
  python3 -c "
import json, sys
d = {'type': sys.argv[1], 'ts': sys.argv[2]}
for kv in sys.argv[3:]:
    k, v = kv.split('=', 1)
    d[k] = int(v) if v.lstrip('-').isdigit() else v
print(json.dumps(d))
" "$type" "$TIMESTAMP" "$@" >> "$METRICS_FILE"
}

# ── Report function ────────────────────────────────────────────────────────────
# Defined before it's called below — a bash function must be defined before
# the line that invokes it runs, and the old layout (defined after `exit 0`)
# meant this line was never reached: `report`/`feature-report` always failed
# with "command not found".
_report() {
  OUT_FILE="${REPO_ROOT}/docs/metrics/session-$(date +%Y-%m-%d)-${BRANCH}.json"

  # `|| true` on each: under `set -o pipefail`, grep finding zero matches
  # (the common case — e.g. no graphify calls yet) makes the whole pipeline
  # exit non-zero, which `set -e` treats as a failed assignment and aborts
  # the script right here, silently, with no output at all.
  GRAPHIFY_CALLS=$(grep '"type": "graphify"' "$METRICS_FILE" 2>/dev/null | wc -l | tr -d ' ' || true)
  BRAIN_READS=$(grep '"type": "brain_read"' "$METRICS_FILE" 2>/dev/null | wc -l | tr -d ' ' || true)
  BRAIN_WRITES=$(grep '"type": "brain_write"' "$METRICS_FILE" 2>/dev/null | wc -l | tr -d ' ' || true)
  FILE_READS=$(grep '"type": "read"' "$METRICS_FILE" 2>/dev/null | wc -l | tr -d ' ' || true)
  FILE_WRITES=$(grep '"type": "write"' "$METRICS_FILE" 2>/dev/null | wc -l | tr -d ' ' || true)
  TEST_RUNS=$(grep '"type": "test_run"' "$METRICS_FILE" 2>/dev/null | wc -l | tr -d ' ' || true)
  TASKS_GREEN=$(grep '"type": "task".*"status": "green"' "$METRICS_FILE" 2>/dev/null | wc -l | tr -d ' ' || true)
  TASKS_TOTAL=$(grep '"type": "task"' "$METRICS_FILE" 2>/dev/null | wc -l | tr -d ' ' || true)

  # AI blob score: functions/methods > 40 lines in changed files.
  # Python has no closing keyword — a function ends when a line drops back
  # to its own indentation or less, so it's counted by indentation, not by
  # matching `end`/`}` (which never appears in .py files and under-counts
  # them to zero). JS/TS/Ruby still match a closer, but `};` (the common
  # Prettier/ESLint style) needs to count too, not just a lone `}`.
  AI_BLOB_SCORE=0
  CHANGED_FILES=$(git -C "$REPO_ROOT" diff --name-only HEAD 2>/dev/null || echo "")
  if [ -n "$CHANGED_FILES" ]; then
    AI_BLOB_SCORE=$(cd "$REPO_ROOT" && echo "$CHANGED_FILES" | python3 -c "
import re, sys

count = 0
for path in sys.stdin.read().splitlines():
    try:
        lines = open(path).readlines()
    except OSError:
        continue

    if path.endswith('.py'):
        i = 0
        while i < len(lines):
            m = re.match(r'^(\s*)def\s', lines[i])
            if not m:
                i += 1
                continue
            indent, start = len(m.group(1)), i
            i += 1
            while i < len(lines) and (not lines[i].strip() or len(lines[i]) - len(lines[i].lstrip()) > indent):
                i += 1
            if i - start > 40:
                count += 1
    else:
        start = None
        for j, line in enumerate(lines):
            if re.search(r'\bdef \b|\bfunction\b|const .*=>', line):
                start = j
            elif start is not None and re.match(r'^\s*(end|};?)\s*$', line):
                if j - start > 40:
                    count += 1
                start = None
print(count)
" 2>/dev/null || echo 0)
  fi

  # Spec drift: files edited outside spec scope (heuristic)
  SPEC_FILE=$(ls "${REPO_ROOT}/docs/superpowers/specs/"*"${BRANCH}"* 2>/dev/null | head -1 || echo "")
  SPEC_DRIFT="unknown"
  if [ -n "$SPEC_FILE" ] && [ -n "$CHANGED_FILES" ]; then
    SPEC_DRIFT="check manually — compare changed files vs spec scope"
  fi

  # Collect test result summaries (suite → last summary line)
  TEST_RESULTS_JSON=$(python3 -c "
import json, sys
results = {}
try:
    for line in open('${METRICS_FILE}'):
        try:
            e = json.loads(line)
            if e.get('type') == 'test_result':
                results[e['suite']] = e['summary']
        except Exception:
            pass
except FileNotFoundError:
    pass
print(json.dumps(results))
" 2>/dev/null || echo '{}')

  mkdir -p "${REPO_ROOT}/docs/metrics"

  export BRANCH TIMESTAMP METRICS_FILE TEST_RESULTS_JSON OUT_FILE \
         GRAPHIFY_CALLS BRAIN_READS BRAIN_WRITES FILE_READS FILE_WRITES \
         TEST_RUNS TASKS_GREEN TASKS_TOTAL AI_BLOB_SCORE SPEC_DRIFT

  python3 - <<'PYEOF'
import json, os

branch     = os.environ["BRANCH"]
timestamp  = os.environ["TIMESTAMP"]
metrics_file = os.environ["METRICS_FILE"]

graphify_calls = int(os.environ["GRAPHIFY_CALLS"])
brain_reads    = int(os.environ["BRAIN_READS"])
brain_writes   = int(os.environ["BRAIN_WRITES"])
file_reads     = int(os.environ["FILE_READS"])
file_writes    = int(os.environ["FILE_WRITES"])
test_runs      = int(os.environ["TEST_RUNS"])
tasks_green    = int(os.environ["TASKS_GREEN"])
tasks_total    = int(os.environ["TASKS_TOTAL"])
ai_blob_score  = int(os.environ["AI_BLOB_SCORE"])
spec_drift     = os.environ["SPEC_DRIFT"]
test_results   = json.loads(os.environ.get("TEST_RESULTS_JSON", "{}"))
out_file       = os.environ["OUT_FILE"]

# Pricing per 1M tokens (USD) — update when Anthropic changes rates
PRICING = {
    "opus":   {"input": 15.00, "output": 75.00},
    "sonnet": {"input":  3.00, "output": 15.00},
    "haiku":  {"input":  0.25, "output":  1.25},
}

cost_by_model = {}
total_cost = 0.0

try:
    with open(metrics_file) as f:
        for line in f:
            try:
                e = json.loads(line)
            except Exception:
                continue
            if e.get("type") not in ("cost", "cost_estimate"):
                continue
            model = e.get("model", "unknown").lower()
            inp   = e.get("input_tokens", 0)
            out   = e.get("output_tokens", 0)
            if model not in cost_by_model:
                cost_by_model[model] = {"input_tokens": 0, "output_tokens": 0, "cost_usd": 0.0}
            cost_by_model[model]["input_tokens"]  += inp
            cost_by_model[model]["output_tokens"] += out
            rates = PRICING.get(model, {"input": 0, "output": 0})
            model_cost = (inp / 1_000_000) * rates["input"] + (out / 1_000_000) * rates["output"]
            cost_by_model[model]["cost_usd"] = round(cost_by_model[model]["cost_usd"] + model_cost, 6)
            total_cost += model_cost
except FileNotFoundError:
    pass

report = {
    "branch": branch,
    "generated_at": timestamp,
    "graphify_calls": graphify_calls,
    "brain_docs_read": brain_reads,
    "brain_docs_written": brain_writes,
    "file_reads": file_reads,
    "file_writes": file_writes,
    "test_runs": test_runs,
    "tasks_completed": tasks_green,
    "tasks_total": tasks_total,
    "ai_blob_score": ai_blob_score,
    "spec_drift": spec_drift,
    "test_results": test_results,
    "cost": {
        "total_usd": round(total_cost, 4),
        "by_model": cost_by_model,
        "note": "Log usage with: scripts/metric-logger.sh cost <opus|sonnet|haiku> <input_tokens> <output_tokens>"
    },
    "thresholds": {
        "ai_blob_score_max": 20,
        "spec_drift_max_pct": 10,
        "min_graphify_calls": 2
    },
    "alerts": []
}
if report["ai_blob_score"] > report["thresholds"]["ai_blob_score_max"]:
    report["alerts"].append("ai_blob_score too high — review long functions")
if report["spec_drift"] not in ("unknown",):
    report["alerts"].append(f"spec_drift: {report['spec_drift']}")
if report["graphify_calls"] < report["thresholds"]["min_graphify_calls"]:
    report["alerts"].append("low graphify usage — did you query the graph before coding?")
if total_cost > 5.0:
    report["alerts"].append(f"session cost ${total_cost:.2f} — review model routing")
with open(out_file, "w") as f:
    json.dump(report, f, indent=2)
print(json.dumps(report, indent=2))
print(f"→ Report saved to {out_file}", file=__import__('sys').stderr)
PYEOF
}

# ── Feature report: per-feature AI vs human comparison ────────────────────────
_feature_report() {
  FEATURE="$1"
  mkdir -p "${REPO_ROOT}/docs/metrics/features"
  OUT_FILE="${REPO_ROOT}/docs/metrics/features/${FEATURE}.json"

  export BRANCH TIMESTAMP METRICS_FILE FEATURE OUT_FILE REPO_ROOT

  python3 - <<'PYEOF'
import json, os, re, math
from datetime import datetime, timezone

metrics_file = os.environ["METRICS_FILE"]
feature      = os.environ["FEATURE"]
out_file     = os.environ["OUT_FILE"]
repo_root    = os.environ["REPO_ROOT"]
timestamp    = os.environ["TIMESTAMP"]

PRICING = {
    "opus":   {"input": 15.00, "output": 75.00},
    "sonnet": {"input":  3.00, "output": 15.00},
    "haiku":  {"input":  0.25, "output":  1.25},
}
HOURLY_RATE_USD = 75  # assumed senior dev rate for cost comparison

def parse_hours(s):
    """Parse '4h', '1.5h', '30m', '2d' into decimal hours."""
    if not s:
        return None
    s = s.strip().lower()
    if s.endswith('d'):
        return float(s[:-1]) * 8
    if s.endswith('m'):
        return float(s[:-1]) / 60
    if s.endswith('h'):
        return float(s[:-1])
    try:
        return float(s)
    except ValueError:
        return None

events = []
try:
    with open(metrics_file) as f:
        for line in f:
            try:
                events.append(json.loads(line))
            except Exception:
                continue
except FileNotFoundError:
    pass

# Tasks with human estimates
tasks = []
for e in events:
    if e.get("type") == "task" and e.get("status") == "green":
        h = parse_hours(e.get("human_estimate", ""))
        tasks.append({
            "task": e["task"],
            "ts":   e.get("ts", ""),
            "human_estimate": e.get("human_estimate", ""),
            "human_hours": h,
        })

# AI session time: span between first and last event
timestamps = [e["ts"] for e in events if "ts" in e]
ai_session_minutes = None
if len(timestamps) >= 2:
    fmt = "%Y-%m-%dT%H:%M:%SZ"
    try:
        t0 = datetime.strptime(timestamps[0],  fmt).replace(tzinfo=timezone.utc)
        t1 = datetime.strptime(timestamps[-1], fmt).replace(tzinfo=timezone.utc)
        ai_session_minutes = round((t1 - t0).total_seconds() / 60, 1)
    except Exception:
        pass

# Costs
total_cost = 0.0
cost_by_model = {}
for e in events:
    if e.get("type") != "cost":
        continue
    model = e.get("model", "unknown").lower()
    inp, out = e.get("input_tokens", 0), e.get("output_tokens", 0)
    if model not in cost_by_model:
        cost_by_model[model] = {"input_tokens": 0, "output_tokens": 0, "cost_usd": 0.0}
    cost_by_model[model]["input_tokens"]  += inp
    cost_by_model[model]["output_tokens"] += out
    rates = PRICING.get(model, {"input": 0, "output": 0})
    c = (inp / 1_000_000) * rates["input"] + (out / 1_000_000) * rates["output"]
    cost_by_model[model]["cost_usd"] = round(cost_by_model[model]["cost_usd"] + c, 6)
    total_cost += c

# Human totals
human_hours_total = sum(t["human_hours"] for t in tasks if t["human_hours"] is not None)
human_cost_usd = round(human_hours_total * HOURLY_RATE_USD, 2)
ai_hours = round((ai_session_minutes or 0) / 60, 2)
ai_cost_usd = round(total_cost, 4)

savings_hours = round(human_hours_total - ai_hours, 2)
savings_usd   = round(human_cost_usd - ai_cost_usd, 2)
multiplier    = round(human_hours_total / ai_hours, 1) if ai_hours > 0 else None

report = {
    "feature": feature,
    "generated_at": timestamp,
    "tasks": tasks,
    "ai": {
        "session_minutes": ai_session_minutes,
        "session_hours": ai_hours,
        "cost_usd": ai_cost_usd,
        "cost_by_model": cost_by_model,
    },
    "human": {
        "estimated_hours": round(human_hours_total, 2),
        "estimated_cost_usd": human_cost_usd,
        "hourly_rate_usd": HOURLY_RATE_USD,
        "note": "Senior dev rate. Adjust HOURLY_RATE_USD in metric-logger.sh."
    },
    "comparison": {
        "hours_saved": savings_hours,
        "cost_saved_usd": savings_usd,
        "speed_multiplier": multiplier,
        "tasks_with_estimates": sum(1 for t in tasks if t["human_hours"] is not None),
        "tasks_without_estimates": sum(1 for t in tasks if t["human_hours"] is None),
    }
}

with open(out_file, "w") as f:
    json.dump(report, f, indent=2)

print(json.dumps(report, indent=2))
print(f"\n→ Feature report saved to {out_file}")
PYEOF
}

# ── Explicit mode ──────────────────────────────────────────────────────────────
if [ "${1:-}" != "" ] && [ "${1:-}" != "{" ]; then
  MODE="$1"
  case "$MODE" in
    graphify)
      _emit graphify "call=${2:-unknown}"
      ;;
    task)
      _emit task "task=${2:-unknown}" "status=${3:-unknown}" "human_estimate=${4:-}"
      ;;
    brain)
      _emit brain_read "doc=${2:-unknown}"
      ;;
    cost)
      _emit cost "model=${2:-unknown}" "input_tokens=${3:-0}" "output_tokens=${4:-0}"
      ;;
    testresult)
      # Usage: scripts/metric-logger.sh testresult <suite> "<summary line>"
      # suite: rspec | vitest | playwright (or any name)
      python3 -c "
import json, sys
print(json.dumps({'type': 'test_result', 'ts': sys.argv[1], 'suite': sys.argv[2], 'summary': sys.argv[3]}))
" "$TIMESTAMP" "${2:-unknown}" "${3:-}" >> "$METRICS_FILE"
      ;;
    report)
      _report
      ;;
    feature-report)
      FEATURE_NAME="${2:-${BRANCH}}"
      _feature_report "$FEATURE_NAME"
      ;;
  esac
  exit 0
fi

# ── Hook mode (stdin JSON from Claude PreToolUse) ──────────────────────────────
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")"
TOOL_INPUT="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('tool_input',{})))" 2>/dev/null || echo "{}")"

case "$TOOL_NAME" in
  Read)
    FILE_PATH="$(echo "$TOOL_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null || echo "")"
    if echo "$FILE_PATH" | grep -q "brain/"; then
      _emit brain_read "doc=${FILE_PATH}"
    else
      _emit read "file=${FILE_PATH}"
    fi
    ;;
  Edit|Write)
    FILE_PATH="$(echo "$TOOL_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null || echo "")"
    if echo "$FILE_PATH" | grep -q "brain/"; then
      _emit brain_write "doc=${FILE_PATH}"
    else
      _emit write "file=${FILE_PATH}"
    fi
    ;;
  Bash|Grep)
    CMD="$(echo "$TOOL_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('command',''))" 2>/dev/null || echo "")"
    if echo "$CMD" | grep -q "graphify"; then
      GCMD="$(echo "$CMD" | grep -oE 'graphify (query|explain|path|update) [^;]+' | head -1 || echo "graphify")"
      _emit graphify "call=${GCMD}"
    elif echo "$CMD" | grep -qE "brain/|obsidian"; then
      _emit brain_read "doc=${CMD}"
    elif echo "$CMD" | grep -qE "rspec|pytest|npm test|bundle exec rspec"; then
      _emit test_run
    fi
    ;;
esac

exit 0
