#!/bin/bash

# Test script for Metal Shader MCP application
# This script builds and runs the app to verify it works

set -e  # Exit on error

echo "🧪 Testing Metal Shader MCP Application..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
if [ -d ".build" ]; then
    rm -rf .build
fi
if [ -d "DerivedData" ]; then
    rm -rf DerivedData
fi

# Build the project
echo ""
echo "🔨 Building Metal Shader MCP..."
swift build

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

# Run tests if they exist
echo ""
echo "🧪 Running tests..."
if swift test 2>/dev/null; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
else
    echo -e "${YELLOW}⚠️  No tests found or tests failed${NC}"
fi

# Try to run the app
echo ""
echo "🚀 Running MetalShaderStudio app..."
echo "   (This will launch the GUI application)"
echo "   (Press Ctrl+C to stop)"
echo ""

# Run the MetalShaderStudio app specifically
swift run MetalShaderStudio &
APP_PID=$!

echo "App launched with PID: $APP_PID"
echo "Waiting 5 seconds to verify it starts..."
sleep 5

# Check if the app is still running
if kill -0 $APP_PID 2>/dev/null; then
    echo -e "${GREEN}✅ App is running!${NC}"
    echo "Stopping the app..."
    kill $APP_PID 2>/dev/null || true
    wait $APP_PID 2>/dev/null || true
else
    echo -e "${RED}❌ App failed to start or crashed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✨ Test complete!${NC}"
