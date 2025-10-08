#!/usr/bin/env bash
set -euo pipefail
COUNT=$(gh pr list --state open --label core-active --json number | jq 'length')
if [ "${COUNT:-0}" -gt 1 ]; then
  echo "ERROR: Single-flight policy violated: $COUNT PRs labeled core-active."
  gh pr list --state open --label core-active || true
  exit 1
fi
echo "Single-flight policy OK."