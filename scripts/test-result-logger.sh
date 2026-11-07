#!/usr/bin/env bash
# test-result-logger.sh — PostToolUse hook that auto-records test_result events
#
# The metric report's "test_results" field (and the PR body's Test Evidence
# section) only ever gets populated by an explicit call to:
#   scripts/metric-logger.sh testresult <suite> "<summary line>"
# Nothing called that automatically — the PreToolUse hook only counts that a
# test command ran (test_run), it never sees the command's output. This hook
# closes that gap: it reads the Bash tool's actual stdout from the
# PostToolUse payload and extracts the summary line itself.
#
# Registered in .claude/settings.json under PostToolUse, matcher "Bash".

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel 2>/dev/null || pwd)"

export HOOK_INPUT="$(cat)"

read -r TOOL_NAME COMMAND OUTPUT < <(python3 -c "
import json, os, base64

try:
    d = json.loads(os.environ['HOOK_INPUT'])
except Exception:
    print('unknown', '', '')
    raise SystemExit

tool_name = d.get('tool_name', 'unknown')
command = d.get('tool_input', {}).get('command', '')
response = d.get('tool_response', '')
if not isinstance(response, str):
    response = json.dumps(response)

# Encode to base64 single-line so embedded newlines/quotes survive the
# \`read\` word-split below without corrupting the shell call.
enc = lambda s: base64.b64encode(s.encode()).decode()
print(tool_name, enc(command), enc(response))
")

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND="$(echo "$COMMAND" | base64 -d)"
OUTPUT="$(echo "$OUTPUT" | base64 -d)"

SUITE=""
case "$COMMAND" in
  *rspec*) SUITE="rspec" ;;
  *vitest*) SUITE="vitest" ;;
  *playwright*) SUITE="playwright" ;;
  *) exit 0 ;;
esac

SUMMARY=""
case "$SUITE" in
  rspec)
    SUMMARY="$(echo "$OUTPUT" | grep -oE '[0-9]+ examples?, [0-9]+ failures?(, [0-9]+ pending)?' | tail -1 || true)"
    ;;
  vitest)
    SUMMARY="$(echo "$OUTPUT" | grep -oE '[0-9]+ (passed|failed)[^0-9]*\([0-9]+\)' | tail -1 || true)"
    ;;
  playwright)
    SUMMARY="$(echo "$OUTPUT" | grep -oE '[0-9]+ (passed|failed)[^,]*' | tail -1 || true)"
    ;;
esac

if [ -n "$SUMMARY" ]; then
  "${REPO_ROOT}/scripts/metric-logger.sh" testresult "$SUITE" "$SUMMARY"
fi

exit 0
