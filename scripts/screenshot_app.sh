#!/bin/bash

# BULLETPROOF MetalShaderStudio Screenshot Script
# Usage: ./scripts/screenshot_app.sh [description] [--expect-tab <repl|library|projects|tools|history>]

APP_NAME="ShaderPlayground"
SCREENSHOT_DIR="Resources/screenshots"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
EXPECT_TAB=""

# Parse args (simple)
DESC=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --expect-tab)
      EXPECT_TAB="$2"; shift 2;;
    *)
      if [[ -z "$DESC" ]]; then DESC="$1"; else DESC+="_$1"; fi; shift;;
  esac
done

if [[ -z "$DESC" ]]; then DESC="app"; fi

# Create directory
mkdir -p "$SCREENSHOT_DIR"

# Filename
OUTPUT_FILE="$SCREENSHOT_DIR/${TIMESTAMP}_${DESC}.png"

# Optional: verify expected tab from status.json
if [[ -n "$EXPECT_TAB" ]]; then
  echo "🔎 Verifying selected tab = '$EXPECT_TAB'"
  STATUS_FILE="Resources/communication/status.json"
  ATTEMPTS=0; MAX_ATTEMPTS=30
  while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
    if [[ -f "$STATUS_FILE" ]]; then
      CURRENT=$(jq -r '.current_tab // empty' "$STATUS_FILE" 2>/dev/null || true)
      if [[ "$CURRENT" == "$EXPECT_TAB" ]]; then
        echo "✅ current_tab matches ($CURRENT)"; break
      fi
    fi
    ATTEMPTS=$((ATTEMPTS+1)); sleep 0.1
  done
  if [[ "$CURRENT" != "$EXPECT_TAB" ]]; then
    echo "❌ Expected tab '$EXPECT_TAB' but status shows '$CURRENT' or missing" >&2
    exit 2
  fi
fi

echo "📸 Capturing $APP_NAME window using CGWindowID..."

# Get the actual CGWindowID using our Swift script
WINDOW_ID=$(python3 "$(dirname "$0")/find_window_id.py" 2>/dev/null | tail -1)

if [[ "$WINDOW_ID" =~ ^[0-9]+$ ]]; then
    echo "✅ Found CGWindowID: $WINDOW_ID"
    
    # Capture the window using the CGWindowID (works even if window is behind others)
    screencapture -l"$WINDOW_ID" -o "$OUTPUT_FILE"
    
    if [ -f "$OUTPUT_FILE" ]; then
        FILE_SIZE=$(stat -f%z "$OUTPUT_FILE")
        echo "✅ Screenshot saved: $OUTPUT_FILE"
        echo "📊 File size: $FILE_SIZE bytes"
        
        # Verify it's not empty
        if [ "$FILE_SIZE" -gt 1000 ]; then
            echo "🔍 Opening screenshot..."
            open "$OUTPUT_FILE"
            echo "✨ SUCCESS! Window captured even if it was in background."
            exit 0
        else
            echo "⚠️ Warning: Screenshot file seems too small"
            exit 1
        fi
    else
        echo "❌ Screenshot file not created"
        exit 1
    fi
else
    echo "❌ Could not get CGWindowID: $WINDOW_ID"
    echo "🔄 Make sure $APP_NAME is running"
    exit 1
fi
