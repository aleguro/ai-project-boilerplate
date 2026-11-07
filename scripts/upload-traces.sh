#!/usr/bin/env bash
# upload-traces.sh — zip Playwright traces and upload to a GitHub release asset.
#
# Usage:
#   scripts/upload-traces.sh                     # uses current branch name as tag suffix
#   scripts/upload-traces.sh --pr 42             # adds download link as PR comment
#
# Output: prints the asset download URL (and trace.playwright.dev link for public repos).

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
BRANCH="$(git -C "$REPO_ROOT" branch --show-current | tr '/' '-')"
DATE="$(date +%Y%m%d-%H%M)"
TAG="e2e-traces-${BRANCH}-${DATE}"
ZIP="$REPO_ROOT/test-results/traces-${BRANCH}.zip"
REPORT_DIR="$REPO_ROOT/playwright-report"
RESULTS_DIR="$REPO_ROOT/test-results"
PR_NUMBER=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr) PR_NUMBER="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Need at least one of report or results
if [ ! -d "$REPORT_DIR" ] && [ ! -d "$RESULTS_DIR" ]; then
  echo "No playwright-report/ or test-results/ found. Run tests first." >&2
  exit 1
fi

# Zip: prefer the HTML report (self-contained viewer) over raw traces
mkdir -p "$(dirname "$ZIP")"
if [ -d "$REPORT_DIR" ]; then
  (cd "$REPO_ROOT" && zip -r "$ZIP" playwright-report/ -x "*.DS_Store" -q)
elif [ -d "$RESULTS_DIR" ]; then
  (cd "$REPO_ROOT" && zip -r "$ZIP" test-results/ -x "*.DS_Store" -q)
fi

ASSET_NAME="$(basename "$ZIP")"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

# Create a lightweight release tag (delete old one with same tag if exists)
gh release delete "$TAG" --yes 2>/dev/null || true
gh release create "$TAG" \
  --title "E2E Traces: ${BRANCH}" \
  --notes "Playwright traces for branch \`${BRANCH}\`. Download and run: \`npx playwright show-report traces-${BRANCH}.zip\`" \
  --prerelease \
  "$ZIP"

ASSET_URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET_NAME}"

echo ""
echo "✓ Traces uploaded: $ASSET_URL"
echo ""
echo "To view locally:"
echo "  gh release download $TAG --pattern '*.zip' -D /tmp"
echo "  npx playwright show-report /tmp/${ASSET_NAME}"

# Post as PR comment if --pr passed
if [ -n "$PR_NUMBER" ]; then
  gh pr comment "$PR_NUMBER" --body "$(cat <<COMMENT
## Playwright Trace Viewer

**[⬇ Download traces](${ASSET_URL})**  \`${ASSET_NAME}\`

To view:
\`\`\`bash
gh release download ${TAG} --pattern '*.zip' -D /tmp
npx playwright show-report /tmp/${ASSET_NAME}
\`\`\`

> Generated from branch \`${BRANCH}\` on ${DATE}
COMMENT
)"
  echo ""
  echo "✓ Comment added to PR #${PR_NUMBER}"
fi
