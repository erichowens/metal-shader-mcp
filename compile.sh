#!/bin/bash

# Compile MetalStudioMCP Final
echo "Compiling MetalStudioMCP Final..."

# Check if all required Swift files exist
REQUIRED_FILES=(
    "MetalStudioMain.swift"
    "MetalStudioMCPCore.swift"
    "MetalStudioMCPComponents.swift"
    "MetalStudioMCPModels.swift"
    "MetalStudioMCPEnhanced.swift"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required file $file not found"
        exit 1
    fi
done

echo "All required files found. Ready to compile."
echo ""
echo "To build this as a macOS app, you need to:"
echo "1. Open Xcode"
echo "2. Create a new macOS App project"
echo "3. Add all the Swift files to the project"
echo "4. Set the deployment target to macOS 13.0+"
echo "5. Build and run"
echo ""
echo "The app includes the following features:"
echo "✓ Resolution controls with presets (720p, 1080p, 4K, Square, Vertical)"
echo "✓ Video export with duration and FPS settings"
echo "✓ Restart shader button in toolbar"
echo "✓ Shader library that switches back to editor after loading"
echo "✓ Real-time parameter extraction"
echo "✓ Live preview with mouse interaction"
echo "✓ MCP server integration"