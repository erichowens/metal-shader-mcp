#!/usr/bin/env bash
set -euo pipefail

# Launch MetalShaderStudio in the background without focusing the window.
# Usage:
#   ./scripts/open_bg.sh [tab]
# Example:
#   ./scripts/open_bg.sh history

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

# Launch in background (no focus) and detach
nohup "$APP_BIN" --tab "$TAB" > "$LOG_DIR/app.log" 2>&1 & disown || true
PID=$!

# The PID printed by 'nohup ... & disown' may not be available in some shells.
# Fall back to pgrep if needed.
if [ -z "${PID:-}" ] || ! ps -p "$PID" > /dev/null 2>&1; then
  PID=$(pgrep -n MetalShaderStudio || true)
fi

echo "Launched MetalShaderStudio (PID ${PID:-unknown}) in background with tab=$TAB"
echo "Logs: $LOG_DIR/app.log"