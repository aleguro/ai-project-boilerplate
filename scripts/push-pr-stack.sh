#!/usr/bin/env bash
# push-pr-stack.sh — creates one PR per stack in a monorepo
#
# Detects which stacks have changes on the current branch vs main,
# then creates a separate PR for each stack with its own base branch.
#
# Usage: scripts/push-pr-stack.sh [base-branch]
#
# Stack detection: based on top-level directories in the monorepo.
# Configure STACK_DIRS below to match your monorepo layout.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
BRANCH="$(git branch --show-current)"
BASE="${1:-main}"

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo "Already on ${BRANCH} — nothing to PR."
  exit 0
fi

# ── Configure your monorepo stack directories here ────────────────────────────
# Format: "directory:stack-label:base-branch"
STACKS=(
  "apps/rails-app:rails:main"
  "apps/react-app:react:main"
  "services/python-service:python:main"
  "infra:infra:main"
)
# ─────────────────────────────────────────────────────────────────────────────

# Find changed files vs base
CHANGED_FILES=$(git diff --name-only "origin/${BASE}...HEAD" 2>/dev/null || git diff --name-only "${BASE}...HEAD" 2>/dev/null || echo "")

if [ -z "$CHANGED_FILES" ]; then
  echo "No changes vs ${BASE}. Nothing to push."
  exit 0
fi

# Push the branch once
echo "Pushing ${BRANCH} to origin..."
git push --set-upstream origin "$BRANCH" 2>&1 || git push origin "$BRANCH" 2>&1

# Find spec file for this branch (for PR body)
SPEC_FILE=$(ls "${REPO_ROOT}/docs/superpowers/specs/"*"${BRANCH#feature/}"* 2>/dev/null | head -1 || echo "")
SPEC_LINK=""
if [ -n "$SPEC_FILE" ]; then
  SPEC_LINK="**Spec:** \`${SPEC_FILE#${REPO_ROOT}/}\`"
fi

# Find session metrics for this branch
METRICS_FILE="${REPO_ROOT}/docs/metrics/session-$(date +%Y-%m-%d)-$(echo "$BRANCH" | tr '/' '-').json"
METRICS_SUMMARY=""
if [ -f "$METRICS_FILE" ]; then
  GRAPHIFY=$(python3 -c "import json; d=json.load(open('${METRICS_FILE}')); print(d.get('graphify_calls',0))" 2>/dev/null || echo "?")
  BRAIN=$(python3 -c "import json; d=json.load(open('${METRICS_FILE}')); print(d.get('brain_docs_read',0))" 2>/dev/null || echo "?")
  TASKS=$(python3 -c "import json; d=json.load(open('${METRICS_FILE}')); print(str(d.get('tasks_completed',0))+'/'+str(d.get('tasks_total',0)))" 2>/dev/null || echo "?/?")
  AI_BLOB=$(python3 -c "import json; d=json.load(open('${METRICS_FILE}')); print(d.get('ai_blob_score',0))" 2>/dev/null || echo "?")
  METRICS_SUMMARY="| graphify calls | ${GRAPHIFY} |
| brain docs read | ${BRAIN} |
| spec tasks completed | ${TASKS} |
| AI blob score | ${AI_BLOB} |"
fi

PR_COUNT=0

for STACK_ENTRY in "${STACKS[@]}"; do
  STACK_DIR="${STACK_ENTRY%%:*}"
  REST="${STACK_ENTRY#*:}"
  STACK_LABEL="${REST%%:*}"
  STACK_BASE="${REST##*:}"

  # Check if any changed file is in this stack's directory
  STACK_CHANGES=$(echo "$CHANGED_FILES" | grep "^${STACK_DIR}/" || true)

  if [ -z "$STACK_CHANGES" ]; then
    continue
  fi

  PR_TITLE="[${STACK_LABEL}] ${BRANCH#feature/}"

  # Collect task list from spec (grep for [x] tasks)
  TASK_LIST=""
  if [ -n "$SPEC_FILE" ]; then
    TASK_LIST=$(grep -E "^\- \[x\].*Stack: ${STACK_LABEL}" "$SPEC_FILE" 2>/dev/null | head -10 || true)
  fi

  PR_BODY="$(cat <<EOF
## ${STACK_LABEL} — ${BRANCH}

${SPEC_LINK}

### Changed files
\`\`\`
$(echo "$STACK_CHANGES" | head -20)
\`\`\`

### Spec tasks completed
${TASK_LIST:-_No spec tasks found for this stack — update the spec._}

### Session metrics
| Metric | Value |
|--------|-------|
${METRICS_SUMMARY:-_Run \`scripts/metric-logger.sh report\` to generate metrics._}

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"

  echo ""
  echo "Creating PR for stack: ${STACK_LABEL} (${STACK_DIR}) → ${STACK_BASE}"

  gh pr create \
    --title "$PR_TITLE" \
    --body "$PR_BODY" \
    --base "$STACK_BASE" \
    --head "$BRANCH" \
    --label "${STACK_LABEL}" 2>/dev/null || \
  gh pr create \
    --title "$PR_TITLE" \
    --body "$PR_BODY" \
    --base "$STACK_BASE" \
    --head "$BRANCH"

  PR_COUNT=$((PR_COUNT + 1))
done

if [ "$PR_COUNT" -eq 0 ]; then
  echo ""
  echo "No stack directories matched the changed files."
  echo "Changed files:"
  echo "$CHANGED_FILES"
  echo ""
  echo "Configure STACK_DIRS in scripts/push-pr-stack.sh to match your monorepo layout."
fi

echo ""
echo "Done — ${PR_COUNT} PR(s) created."
