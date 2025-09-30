#!/usr/bin/env bash
set -euo pipefail

# Launch MetalShaderStudio in the foreground (active window) by default.
# Usage:
#   ./scripts/open_fg.sh [tab]
# Example:
#   ./scripts/open_fg.sh history
# Notes:
# - Builds the app if missing
# - Starts it (restarting any prior instance)
# - Brings its window to the foreground

TAB="${1:-history}"
LOG_DIR=".runlogs"
APP_BIN=".build/debug/MetalShaderStudio"

mkdir -p "$LOG_DIR"

# Build the app if the binary is missing
if [ ! -x "$APP_BIN" ]; then
  echo "Building MetalShaderStudio..."
  swift build --configuration debug
fi

# Stop any previous instances (best-effort)
pkill -f MetalShaderStudio || true

# Launch and capture logs
nohup "$APP_BIN" --tab "$TAB" > "$LOG_DIR/app.log" 2>&1 & disown || true
PID=$!

# Fallback to pgrep if needed
if [ -z "${PID:-}" ] || ! ps -p "$PID" > /dev/null 2>&1; then
  sleep 0.5
  PID=$(pgrep -n MetalShaderStudio || true)
fi

echo "Launched MetalShaderStudio (PID ${PID:-unknown}) with tab=$TAB"
echo "Logs: $LOG_DIR/app.log"

# Give app a moment to initialize before focusing
sleep 0.8

# Bring to front using System Events
osascript <<'APPLESCRIPT' || true
tell application "System Events"
  try
    set frontmost of (first process whose name contains "MetalShaderStudio") to true
  on error
    -- Fallback to historical alt name
    try
      set frontmost of (first process whose name contains "ShaderPlayground") to true
    end try
  end try
end tell
APPLESCRIPT

# As a secondary nudge (some environments): activate by bundle id if we can derive one from the binary's Info.plist
if [ -d "$APP_BIN" ]; then
  # If it were an .app bundle (not typical for SPM exec), activate via bundle id
  BUNDLE_ID=$(defaults read "$APP_BIN/Contents/Info" CFBundleIdentifier 2>/dev/null || true)
  if [ -n "${BUNDLE_ID:-}" ]; then
    osascript -e 'tell application id "'"$BUNDLE_ID"'" to activate' || true
  fi
fi

exit 0