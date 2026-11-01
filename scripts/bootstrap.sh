#!/usr/bin/env bash
# bootstrap.sh — run once after cloning the boilerplate
# Usage: make bootstrap PROJECT=my-project
#    or: bash scripts/bootstrap.sh my-project

set -euo pipefail

PROJECT="${1:-${PROJECT:-}}"

if [ -z "$PROJECT" ]; then
  echo "Error: project name required."
  echo "Usage: make bootstrap PROJECT=my-project"
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "Bootstrapping project: ${PROJECT}"

# 1. Replace {{PROJECT_NAME}} in CLAUDE.md, README.md, brain/CLAUDE.md
sed -i.bak "s/{{PROJECT_NAME}}/${PROJECT}/g" "${REPO_ROOT}/CLAUDE.md" && rm -f "${REPO_ROOT}/CLAUDE.md.bak"
sed -i.bak "s/{{PROJECT_NAME}}/${PROJECT}/g" "${REPO_ROOT}/README.md" && rm -f "${REPO_ROOT}/README.md.bak"
sed -i.bak "s/{{PROJECT_NAME}}/${PROJECT}/g" "${REPO_ROOT}/brain/CLAUDE.md" && rm -f "${REPO_ROOT}/brain/CLAUDE.md.bak"

echo "  [ok] Replaced {{PROJECT_NAME}} with '${PROJECT}'"

# 2. Configure git alias push-pr
git config alias.push-pr "!f() { ${REPO_ROOT}/scripts/push-pr.sh \"\$@\"; }; f"
echo "  [ok] Git alias 'push-pr' configured"

# 3. Install git post-commit hook — auto-updates graphify graph after every commit
HOOK_FILE="${REPO_ROOT}/.git/hooks/post-commit"
cat > "$HOOK_FILE" << 'HOOK'
#!/usr/bin/env bash
# Auto-update graphify knowledge graph after each commit
REPO_ROOT="$(git rev-parse --show-toplevel)"
bash "${REPO_ROOT}/scripts/graphify-update.sh" 2>/dev/null || true
HOOK
chmod +x "$HOOK_FILE"
echo "  [ok] git post-commit hook installed (graphify-update runs automatically)"

# 4. Initialize graphify (build initial knowledge graph)
if python3 -c "import graphify" &>/dev/null 2>&1; then
  echo "  [..] Initializing graphify knowledge graph..."
  bash "${REPO_ROOT}/scripts/graphify-update.sh" init
  echo "  [ok] graphify initialized — graph will update automatically on every commit"
else
  echo "  [!] graphify not found — install it, then run: make graphify-init"
  echo "      pip install graphify-cli"
fi

# 5. Verify Node.js (required for Playwright MCP)
if command -v node &>/dev/null; then
  echo "  [ok] node $(node --version) found"
else
  echo "  [!] Node.js not found. Install: brew install node"
fi

# 6. Verify Playwright MCP server
if command -v npx &>/dev/null && npx --yes @playwright/mcp@latest --version &>/dev/null 2>&1; then
  echo "  [ok] Playwright MCP available"
else
  echo "  [!] Playwright MCP not found. Install: npm install -g @playwright/mcp"
  echo "      Then add to .claude/settings.json (see docs/superpowers/e2e/README.md)"
fi

# 7. Create brain/Metrics/ if it doesn't exist
mkdir -p "${REPO_ROOT}/brain/Metrics"
if [ ! -f "${REPO_ROOT}/brain/Metrics/index.md" ]; then
  cat > "${REPO_ROOT}/brain/Metrics/index.md" << 'METRICS_INDEX'
---
title: Metrics
tags: [index, metrics]
created: PLACEHOLDER_DATE
updated: PLACEHOLDER_DATE
status: active
type: index
---

# Metrics

Session and feature productivity reports. Generated automatically by `/save`.

## Index

_Session reports and feature comparisons appear here after `/save`._
METRICS_INDEX
  # Replace date placeholder
  TODAY="$(date +%Y-%m-%d)"
  sed -i.bak "s/PLACEHOLDER_DATE/${TODAY}/g" "${REPO_ROOT}/brain/Metrics/index.md" \
    && rm -f "${REPO_ROOT}/brain/Metrics/index.md.bak"
  echo "  [ok] brain/Metrics/ created"
fi

echo ""
echo "Bootstrap complete. Everything is automatic from here:"
echo "  - graphify updates on every git commit (post-commit hook)"
echo "  - metrics save to brain/Metrics/ on every /save"
echo "  - feature comparisons generate on /save when a feature is shipped"
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md to describe your project structure"
echo "  2. Open Claude Code and say: 'I want to build [feature]. Load spec-driven-development.'"
echo "  3. After each session, tell Claude: /save"
