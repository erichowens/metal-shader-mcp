#!/usr/bin/env bash
set -euo pipefail
NUM="${1:-}"
if [[ -z "$NUM" ]]; then
  echo "Usage: $0 <pr-number>" >&2
  exit 2
fi
BODY=$(gh pr view "$NUM" --json body -q .body)
missing=0
for section in "MCP-first and Priority" "Visual Evidence" "Tests" "WARP After-Action"; do
  echo "$BODY" | grep -q "$section" || { echo "Missing section: $section"; missing=1; }
done
exit $missing