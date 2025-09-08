#!/usr/bin/env bash
set -euo pipefail

# Requirements
command -v jq >/dev/null 2>&1 || { echo "jq is required; skipping EPIC sync" >&2; exit 0; }
command -v gh >/dev/null 2>&1 || { echo "gh CLI is required; skipping EPIC sync" >&2; exit 0; }

ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$ROOT_DIR"

if [[ ! -f docs/EPICS.json ]]; then
  echo "docs/EPICS.json not found; skipping sync" >&2
  exit 0
fi

# Get recent commit info
SHA_FULL=$(git rev-parse HEAD)
SHA=$(git rev-parse --short HEAD)
MSG=$(git log -1 --pretty=%B | sed -e 's/\r$//')
URL=$(git remote get-url origin 2>/dev/null | sed 's/.git$//')
COMMIT_URL="$URL/commit/$SHA_FULL"
PR_NUMBER=${PR_NUMBER:-}
PR_URL=""
if [[ -n "${PR_NUMBER}" ]]; then
  PR_URL="$URL/pull/$PR_NUMBER"
fi

# Changed files in the last commit
mapfile -t CHANGED < <(git diff-tree --no-commit-id --name-only -r "$SHA_FULL")

# Load EPIC mapping (optional)
MAPPING_FILE="docs/EPICS_MAP.json"
TARGET_EPICS=()
if [[ -f "$MAPPING_FILE" ]]; then
  # Build list of (glob -> epics[]) pairs
  MAP_COUNT=$(jq '.mappings | length' "$MAPPING_FILE")
  for ((i=0; i<MAP_COUNT; i++)); do
    GLOBS=( $(jq -r ".mappings[$i].globs[]" "$MAPPING_FILE") )
    EPICS=( $(jq -r ".mappings[$i].epics[]" "$MAPPING_FILE") )
    # For each changed file, see if it matches one of the globs
    for f in "${CHANGED[@]}"; do
      for g in "${GLOBS[@]}"; do
        # pattern match using [[ string == pattern ]]
        if [[ "$f" == $g ]]; then
          for e in "${EPICS[@]}"; do
            TARGET_EPICS+=("$e")
          done
        fi
      done
    done
  done
fi

# Fallback to all epics if no match
if [[ ${#TARGET_EPICS[@]} -eq 0 ]]; then
  mapfile -t TARGET_EPICS < <(jq -r '.epics[].number' docs/EPICS.json)
fi

# De-duplicate
if [[ ${#TARGET_EPICS[@]} -gt 0 ]]; then
  readarray -t TARGET_EPICS < <(printf '%s
' "${TARGET_EPICS[@]}" | awk '!seen[$0]++')
fi

# Collect screenshot evidence in this commit (filenames only)
SCREENSHOTS=()
for f in "${CHANGED[@]}"; do
  if [[ "$f" == Resources/screenshots/*.png || "$f" == Resources/screenshots/*.jpg || "$f" == Resources/screenshots/*.jpeg ]]; then
    SCREENSHOTS+=("$f")
  fi
done

# Build comment body
BODY=$(cat <<'EOF'
## Progress Update

- Commit: COMMIT_URL_HERE
- SHA: SHA_HERE
EOF
)

# Append message (quoted literal to avoid shell eval)
BODY+=$'\n- Message:\n\n```
'
BODY+="$MSG"
BODY+=$'\n```
'

# Append PR if available
if [[ -n "$PR_URL" ]]; then
  BODY+=$"\n- PR: $PR_URL\n"
fi

# Append changed files summary
BODY+=$'\n### Changed files\n'
for f in "${CHANGED[@]}"; do
  BODY+=$"- $f\n"
done

# Append screenshots if any
if [[ ${#SCREENSHOTS[@]} -gt 0 ]]; then
  BODY+=$'\n### Visual Evidence\n'
  for s in "${SCREENSHOTS[@]}"; do
    BODY+=$"- $s\n"
  done
fi

# Substitute placeholders
BODY=${BODY/COMMIT_URL_HERE/$COMMIT_URL}
BODY=${BODY/SHA_HERE/$SHA}

# Post to relevant EPICs
for N in "${TARGET_EPICS[@]}"; do
  gh issue comment "$N" --body "$BODY" || true
done

echo "Posted targeted progress comment to EPIC issues: ${TARGET_EPICS[*]}"

