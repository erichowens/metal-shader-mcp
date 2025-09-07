#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-}"  # optional override
ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$ROOT_DIR"

if [[ ! -f docs/EPICS.json ]]; then
  echo "docs/EPICS.json not found; skipping sync" >&2
  exit 0
fi

# Get recent commit info
SHA=$(git rev-parse --short HEAD)
MSG=$(git log -1 --pretty=%B | sed -e 's/\r$//')
URL=$(git remote get-url origin 2>/dev/null | sed 's/.git$//')
COMMIT_URL="$URL/commit/$(git rev-parse HEAD)"

BODY=$(cat <<EOF
Progress update: $SHA

- Commit: $COMMIT_URL
- Message:

```
$MSG
```

Artifacts:
- CHANGELOG.md updated if applicable
- Sessions (if any): Resources/sessions/
EOF
)

EPIC_NUMBERS=$(jq -r '.epics[].number' docs/EPICS.json)
for N in $EPIC_NUMBERS; do
  gh issue comment "$N" --body "$BODY" || true
done

echo "Posted progress comment to EPIC issues."

