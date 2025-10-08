#!/usr/bin/env bash
set -euo pipefail

# Bring the MetalShaderStudio window to the foreground on demand.
# This does not launch the app; run open_bg.sh first if needed.

# Try MetalShaderStudio process name first
osascript <<'APPLESCRIPT' || true
tell application "System Events"
  set frontmost of (first process whose name contains "MetalShaderStudio") to true
end tell
APPLESCRIPT

# Fallback to alternate owner name used in some environments
osascript <<'APPLESCRIPT' || true
tell application "System Events"
  set frontmost of (first process whose name contains "ShaderPlayground") to true
end tell
APPLESCRIPT

echo "Brought MetalShaderStudio (or ShaderPlayground) window to the front"