#!/usr/bin/env bash
set -euo pipefail

# Switch to a tab and capture a background-safe screenshot of the app window.
# Usage:
#   ./scripts/screenshot_tab.sh <repl|library|projects|tools|history> "description"
# Example:
#   ./scripts/screenshot_tab.sh history "history_tab_open"

TAB="${1:-history}"
DESC="${2:-ui}"

# Set tab via command bridge
"$(dirname "$0")/set_tab.sh" "$TAB"
# Give app time to process and write status.json
sleep 0.5

# Capture screenshot and verify expected tab
"$(dirname "$0")/screenshot_app.sh" "$DESC" --expect-tab "$TAB"