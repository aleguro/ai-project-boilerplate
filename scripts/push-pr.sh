#!/usr/bin/env bash
# push-pr.sh — wraps git push and auto-creates a PR for non-main branches
# Usage: git push-pr [remote] [branch]  OR  scripts/push-pr.sh [remote] [branch]

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
BRANCH="$(git branch --show-current)"

# Run git push with all passed arguments
git push "$@"

# Skip PR creation for main/master
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  exit 0
fi

# Create PR in background so shell returns immediately
"${REPO_ROOT}/scripts/create-pr.sh" &
echo "PR creation running in background..."
