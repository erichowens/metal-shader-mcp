#!/usr/bin/env bash
set -euo pipefail

# CI UI smoke: build, launch History tab, verify status.json current_tab
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

# Ensure deps for scripts
if ! command -v jq >/dev/null 2>&1; then
  echo "Installing jq..."
  brew update >/dev/null 2>&1 || true
  brew install jq >/dev/null 2>&1 || true
fi

# Build with SwiftPM
echo "Building with Swift Package Manager..."
swift build --configuration debug

# Copy executable to root for convenience
cp .build/debug/MetalShaderStudio ./MetalShaderStudio || {
  echo "❌ Failed to copy executable" >&2
  exit 1
}

# Clean comm dir
rm -f Resources/communication/status.json || true
mkdir -p Resources/communication

# Launch into history tab
./MetalShaderStudio --tab history >/dev/null 2>&1 &
APP_PID=$!
# Give it time to boot
sleep 2

# Verify status.json
if [[ ! -f Resources/communication/status.json ]]; then
  echo "❌ status.json not written" >&2
  kill $APP_PID || true
  exit 1
fi
TAB=$(jq -r '.current_tab // empty' Resources/communication/status.json)
if [[ "$TAB" != "history" ]]; then
  echo "❌ Expected history tab, got '$TAB'" >&2
  kill $APP_PID || true
  exit 1
fi

echo "✅ current_tab=history"

# Try a best-effort screenshot (non-fatal)
if [[ -x scripts/screenshot_app.sh ]]; then
  set +e
  ./scripts/screenshot_app.sh "ci_history" --expect-tab history || echo "⚠️ Screenshot step failed (non-fatal)"
  set -e
fi

# Cleanup app process
kill $APP_PID || true
exit 0
