#!/usr/bin/env bash
# graphify-update.sh — init or update the graphify graph for the current project
# Called by Makefile and by the PostToolUse hook after file edits.
#
# Usage:
#   scripts/graphify-update.sh        # update existing graph
#   scripts/graphify-update.sh init   # init + store python path

set -euo pipefail

MODE="${1:-update}"

if [ ! -f "graphify-out/.graphify_python" ] && [ "$MODE" != "init" ]; then
  echo "graphify-out/.graphify_python not found — run 'make graphify-init' first."
  exit 0
fi

if [ "$MODE" = "init" ]; then
  GPY=$(python3 -c "import graphify; import sys; print(sys.executable)" 2>/dev/null || echo "python3")
  echo "Using Python: $GPY"
  "$GPY" -m graphify init .
  mkdir -p graphify-out
  echo "$GPY" > graphify-out/.graphify_python
  echo "graphify initialized. Graph at graphify-out/"
else
  GPY=$(cat graphify-out/.graphify_python)
  "$GPY" -m graphify update . 2>/dev/null || true
fi
