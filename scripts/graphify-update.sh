#!/usr/bin/env bash
# graphify-update.sh — build or update the graphify graph for the current project
# Uses the real graphify CLI (package: graphifyy). No custom init/update protocol needed.
#
# Usage:
#   scripts/graphify-update.sh        # build or update the graph

set -euo pipefail

if ! command -v graphify >/dev/null 2>&1; then
  echo "graphify not found on PATH — install it: uv tool install graphifyy (or: pipx install graphifyy)"
  exit 0
fi

graphify update .
