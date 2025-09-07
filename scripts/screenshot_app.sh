#!/bin/bash

# BULLETPROOF MetalShaderStudio Screenshot Script
# Usage: ./scripts/screenshot_reliable.sh [description]

APP_NAME="ShaderPlayground"
SCREENSHOT_DIR="Resources/screenshots"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Create directory
mkdir -p "$SCREENSHOT_DIR"

# Generate filename with optional description
if [ -n "$1" ]; then
    OUTPUT_FILE="$SCREENSHOT_DIR/${TIMESTAMP}_${1}.png"
else
    OUTPUT_FILE="$SCREENSHOT_DIR/${TIMESTAMP}_app.png"
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
