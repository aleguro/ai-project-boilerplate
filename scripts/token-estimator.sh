#!/usr/bin/env bash
# token-estimator.sh — PostToolUse hook that estimates token usage per tool call
#
# How the heuristic works:
#   input_tokens  ≈ len(tool_response_json) / 4   (model reads the result back)
#   output_tokens ≈ len(tool_input_json) / 4 + 60  (model generated the call)
#
# Accuracy: rough ±30%. Good enough for "am I burning $10 on Opus?" checks.
# The estimate accumulates in /tmp like the other metrics and rolls up in `make metrics-report`.
#
# Active model: write the model name to .claude/.active-model when you switch.
# e.g.  echo "opus" > .claude/.active-model
# Defaults to "sonnet" when the file is absent.

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel 2>/dev/null || pwd)"
BRANCH="$(git -C "${REPO_ROOT}" branch --show-current 2>/dev/null | tr '/' '-')"
BRANCH="${BRANCH:-unknown}"
METRICS_FILE="/tmp/claude-metrics-${BRANCH}.jsonl"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Determine active model (default: sonnet)
MODEL_FILE="${REPO_ROOT}/.claude/.active-model"
MODEL="sonnet"
if [ -f "$MODEL_FILE" ]; then
  MODEL="$(cat "$MODEL_FILE" | tr -d '[:space:]')"
fi

# Read PostToolUse payload from stdin
INPUT="$(cat)"

# Extract tool name, input, response via python3
read -r TOOL_NAME TOOL_INPUT_LEN TOOL_RESPONSE_LEN < <(python3 - <<'PYEOF'
import sys, json

try:
    d = json.load(sys.stdin)
except Exception:
    print("unknown 0 0")
    sys.exit(0)

tool_name     = d.get("tool_name", "unknown")
tool_input    = json.dumps(d.get("tool_input", {}))
tool_response = d.get("tool_response", "")
if not isinstance(tool_response, str):
    tool_response = json.dumps(tool_response)

print(tool_name, len(tool_input), len(tool_response))
PYEOF
<<< "$INPUT")

# Estimate tokens
# output: the model generated the tool call itself
OUTPUT_TOKENS=$(python3 -c "print(max(1, int(${TOOL_INPUT_LEN:-0} / 4) + 60))")
# input: the model consumed the tool response
INPUT_TOKENS=$(python3 -c "print(max(1, int(${TOOL_RESPONSE_LEN:-0} / 4)))")

# Skip trivially small calls (no-op tools, empty responses)
if [ "$INPUT_TOKENS" -lt 5 ] && [ "$OUTPUT_TOKENS" -lt 65 ]; then
  exit 0
fi

echo "{\"type\":\"cost_estimate\",\"model\":\"${MODEL}\",\"tool\":\"${TOOL_NAME}\",\"input_tokens\":${INPUT_TOKENS},\"output_tokens\":${OUTPUT_TOKENS},\"ts\":\"${TIMESTAMP}\"}" >> "$METRICS_FILE"
