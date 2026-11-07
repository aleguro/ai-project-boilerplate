#!/usr/bin/env bash
# e2e-to-gif.sh — convert Playwright .webm recordings to GIFs and upload as
# GitHub release assets, then post a download table as a PR comment.
#
# Usage:
#   scripts/e2e-to-gif.sh                  # converts all webm in test-results/
#   scripts/e2e-to-gif.sh --pr 42          # also posts a PR comment with the GIFs
#   scripts/e2e-to-gif.sh --width 640      # override output width (default: 800)
#
# Requirements: ffmpeg, gh (GitHub CLI authenticated)

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
RESULTS_DIR="${REPO_ROOT}/test-results"
GIF_DIR="${REPO_ROOT}/test-results/gifs"
WIDTH=800
PR_NUMBER=""
BRANCH="$(git -C "$REPO_ROOT" branch --show-current)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)    PR_NUMBER="$2"; shift 2 ;;
    --width) WIDTH="$2";     shift 2 ;;
    *)       shift ;;
  esac
done

if ! command -v ffmpeg &>/dev/null; then
  echo "ffmpeg not found. Install with: brew install ffmpeg" >&2
  exit 1
fi

# Find all webm recordings
WEBM_FILES=$(find "$RESULTS_DIR" -name "*.webm" 2>/dev/null | sort || echo "")
if [ -z "$WEBM_FILES" ]; then
  echo "No .webm files found in test-results/. Run Playwright with video:'on' first." >&2
  exit 1
fi

mkdir -p "$GIF_DIR"

# Convert each .webm → .gif
GIF_FILES=()
echo "Converting recordings..."
while IFS= read -r webm; do
  # Derive readable name: extract TC-NN + everything after the 5-char hash
  # Input: auth-login-TC-01-Login-pag-3069c-rd-field-and-sign-in-button-chromium
  # Output: TC-01-rd-field-and-sign-in-button
  test_dir=$(basename "$(dirname "$webm")")
  short=$(echo "$test_dir" | sed 's/-chromium$//' \
    | python3 -c "
import sys, re
s = sys.stdin.read().strip()
# Find TC-NN, grab it + skip the truncated middle word (5-char hash + next segment)
m = re.search(r'(TC-\d+)-[^-]+-[^-]+-[^-]+-[a-f0-9]{5}-(.+)', s)
if m:
    print(m.group(1) + '-' + m.group(2))
else:
    # fallback: strip hash and chromium
    print(re.sub(r'-[a-f0-9]{5}-', '-', s)[:60])
")
  gif="${GIF_DIR}/${short}.gif"

  ffmpeg -i "$webm" \
    -vf "fps=8,scale=${WIDTH}:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse" \
    -loop 0 \
    "$gif" -y -loglevel error

  GIF_FILES+=("$gif")
  echo "  ✓ $(basename "$gif")"
done <<< "$WEBM_FILES"

DATE="$(date +%Y%m%d-%H%M)"
TAG="e2e-recordings-$(echo "$BRANCH" | tr '/' '-')-${DATE}"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

echo ""
echo "Uploading ${#GIF_FILES[@]} GIF(s) as release assets..."

gh release delete "$TAG" --yes 2>/dev/null || true
gh release create "$TAG" \
  --title "E2E Recordings: ${BRANCH}" \
  --notes "Playwright screen recordings for branch \`${BRANCH}\`." \
  --prerelease \
  "${GIF_FILES[@]}"

MARKDOWN="## E2E Recordings

| Test | Recording |
|------|-----------|"
for gif in "${GIF_FILES[@]}"; do
  filename=$(basename "$gif")
  asset_url="https://github.com/${REPO}/releases/download/${TAG}/${filename}"
  label=$(basename "$gif" .gif | sed 's/-/ /g' | sed 's/TC /TC-/; s/  */ /g')
  MARKDOWN="${MARKDOWN}
| ${label} | [▶ Download GIF](${asset_url}) |"
done
MARKDOWN="${MARKDOWN}

> Release: https://github.com/${REPO}/releases/tag/${TAG}"

echo "✓ Uploaded to: https://github.com/${REPO}/releases/tag/${TAG}"

# Post as PR comment if --pr passed
if [ -n "$PR_NUMBER" ]; then
  gh pr comment "$PR_NUMBER" --body "$MARKDOWN"
  echo "✓ Comment added to PR #${PR_NUMBER}"
fi
