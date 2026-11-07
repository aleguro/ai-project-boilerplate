#!/usr/bin/env bash
# e2e-to-gif.sh — re-runs the Playwright suite (needs use.video set in
# playwright.config.ts), converts the recordings to GIFs, uploads them as
# GitHub release assets (not committed to git — keeps the repo small), then
# posts a download table as a PR comment.
#
# Usage:
#   scripts/e2e-to-gif.sh                  # converts all recordings from a fresh run
#   scripts/e2e-to-gif.sh --pr 42          # also posts a PR comment with the GIFs
#   scripts/e2e-to-gif.sh --width 640      # override output width (default: 800)
#
# Requirements: ffmpeg, gh (GitHub CLI authenticated), the app stack already
# running (docker compose up) since this re-runs the suite against it.

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
GIF_DIR="${REPO_ROOT}/tests/e2e/artifacts/gifs"
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

E2E_DIR="${REPO_ROOT}/tests/e2e"
JSON_REPORT="$(mktemp)"

# Re-run the suite with the json reporter to get an exact title -> video path
# mapping. Playwright's own path sanitization truncates a long test title and
# splices in a hash (e.g. "TC-04-logging-in-..." becomes "TC-2099d-...",
# merging the hash into what looks like the TC number) once the combined
# describe+title+project path gets long enough — regex-guessing the real
# title back out of that mangled directory name doesn't reliably work. The
# json reporter's `attachments` array gives the real title and video path
# directly, no guessing.
echo "Running suite (json reporter, for title -> video mapping)..."
(cd "$E2E_DIR" && npx playwright test --reporter=json > "$JSON_REPORT" 2>/dev/null) || true

mkdir -p "$GIF_DIR"

# Convert each (title, video path) pair -> .gif
GIF_FILES=()
echo "Converting recordings..."
while IFS=$'\t' read -r title webm; do
  [ -z "$webm" ] && continue
  short=$(python3 -c "
import re, sys
t = sys.argv[1]
t = re.sub(r'[^A-Za-z0-9 .-]', '', t)
t = re.sub(r'\s+', '-', t.strip())
print(t[:80])
" "$title")
  gif="${GIF_DIR}/${short}.gif"

  ffmpeg -i "$webm" \
    -vf "fps=8,scale=${WIDTH}:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse" \
    -loop 0 \
    "$gif" -y -loglevel error

  GIF_FILES+=("$gif")
  echo "  ✓ $(basename "$gif")"
done < <(python3 -c "
import json
with open('${JSON_REPORT}') as f:
    data = json.load(f)

def walk(suite, prefix=''):
    title = suite.get('title', '')
    title_prefix = prefix if title.endswith('.ts') else f'{prefix} {title}'.strip()
    for spec in suite.get('specs', []):
        for test in spec.get('tests', []):
            for result in test.get('results', []):
                for att in result.get('attachments', []):
                    if att.get('name') == 'video' and att.get('path'):
                        print(f'{title_prefix} {spec[\"title\"]}'.strip() + '\t' + att['path'])
    for child in suite.get('suites', []):
        walk(child, title_prefix)

for top_suite in data.get('suites', []):
    walk(top_suite)
" 2>/dev/null)

rm -f "$JSON_REPORT"

if [ ${#GIF_FILES[@]} -eq 0 ]; then
  echo "No video attachments found in the test run. Is use.video set in playwright.config.ts?" >&2
  exit 1
fi

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
"
for gif in "${GIF_FILES[@]}"; do
  filename=$(basename "$gif")
  asset_url="https://github.com/${REPO}/releases/download/${TAG}/${filename}"
  label=$(basename "$gif" .gif | sed 's/-/ /g' | sed 's/TC /TC-/; s/  */ /g')
  # Image syntax (not a link) so GitHub renders the GIF inline, playing, in
  # the comment body itself — a link would just be a click-to-download.
  MARKDOWN="${MARKDOWN}
### ${label}
![${label}](${asset_url})
"
done
MARKDOWN="${MARKDOWN}
> Release: https://github.com/${REPO}/releases/tag/${TAG}"

echo "✓ Uploaded to: https://github.com/${REPO}/releases/tag/${TAG}"

# Post as PR comment if --pr passed
if [ -n "$PR_NUMBER" ]; then
  gh pr comment "$PR_NUMBER" --body "$MARKDOWN"
  echo "✓ Comment added to PR #${PR_NUMBER}"
fi
