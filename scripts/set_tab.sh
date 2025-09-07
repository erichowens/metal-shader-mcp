#!/usr/bin/env bash
set -euo pipefail
TAB="${1:-history}"
mkdir -p Resources/communication
cat > Resources/communication/commands.json <<JSON
{
  "action": "set_tab",
  "tab": "${TAB}",
  "timestamp": $(date +%s)
}
JSON

