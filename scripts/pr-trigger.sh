#!/usr/bin/env bash
# pr-trigger.sh — called by Claude PostToolUse hook on Bash tool
# Detects "git push <remote> <branch>" and calls create-pr.sh

set -euo pipefail

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")"

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

CMD="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")"

# Match: git push <remote> <branch> (not just git push origin main)
if echo "$CMD" | grep -qE "^git push [a-zA-Z0-9_.-]+ [a-zA-Z0-9_./:-]+$"; then
  BRANCH="$(git -C "$(dirname "$0")/.." branch --show-current 2>/dev/null || echo "")"
  # Don't auto-create PR for main/master
  if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
    "$(dirname "$0")/create-pr.sh" &
  fi
fi

exit 0
