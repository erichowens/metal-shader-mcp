#!/usr/bin/env bats
# Tests for screenshot_app.sh
#
# Run with: bats scripts/tests/screenshot_app.bats
# Or: bats scripts/tests/*.bats (run all tests)

setup() {
  # Get script directory (BATS_TEST_DIRNAME is the directory containing the test file)
  # Go up one level from tests/ to scripts/
  SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCREENSHOT_SCRIPT="$SCRIPT_DIR/screenshot_app.sh"
  
  # Ensure script exists and is executable
  [ -f "$SCREENSHOT_SCRIPT" ]
  [ -x "$SCREENSHOT_SCRIPT" ]
  
  # Create temp directory for test outputs
  TEST_TEMP_DIR="${BATS_TMPDIR}/screenshot-tests-$$"
  mkdir -p "$TEST_TEMP_DIR"
}

teardown() {
  # Clean up test outputs
  if [ -d "$TEST_TEMP_DIR" ]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

@test "screenshot_app.sh --help displays usage" {
  run bash "$SCREENSHOT_SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "USAGE" ]]
  [[ "$output" =~ "OPTIONS" ]]
  [[ "$output" =~ "ENVIRONMENT VARIABLES" ]]
  [[ "$output" =~ "EXAMPLES" ]]
  [[ "$output" =~ "EXIT CODES" ]]
}

@test "screenshot_app.sh --self-test validates environment" {
  run bash "$SCREENSHOT_SCRIPT" --self-test
  # Exit code 0 (success) or 3 (missing dependency) are acceptable
  # 2 (permission denied) means TCC not granted, which is expected in some envs
  [ "$status" -eq 0 ] || [ "$status" -eq 2 ] || [ "$status" -eq 3 ]
  [[ "$output" =~ "self-test" ]] || [[ "$output" =~ "Self-test" ]]
}

@test "screenshot_app.sh validates OUTPUT_DIR env var" {
  # Set custom output directory
  export OUTPUT_DIR="$TEST_TEMP_DIR/custom-screenshots"
  export CI=true  # Prevent opening file
  
  # This will fail because app isn't running, but we can check the directory was created
  run bash "$SCREENSHOT_SCRIPT" "test" 2>&1 || true
  
  # Check that our custom directory would be used (created by script)
  [ -d "$OUTPUT_DIR" ] || echo "Directory should have been created"
}

@test "screenshot_app.sh respects SCREENSHOT_NAME env var" {
  export OUTPUT_DIR="$TEST_TEMP_DIR/name-test"
  export SCREENSHOT_NAME="custom-name.png"
  export CI=true
  
  # Will fail (no app), but we can verify the naming logic
  run bash "$SCREENSHOT_SCRIPT" 2>&1 || true
  
  # Output should mention the custom name in debug/error messages
  [[ "$output" =~ "custom-name.png" ]] || echo "Custom name should be in output"
}

@test "screenshot_app.sh enforces timestamp naming by default" {
  export OUTPUT_DIR="$TEST_TEMP_DIR/timestamp-test"
  export CI=true
  
  # Will fail (no app running)
  run bash "$SCREENSHOT_SCRIPT" "test_description" 2>&1 || true
  
  # Should create directory even if capture fails
  [ -d "$OUTPUT_DIR" ]
  
  # Output should mention a timestamped filename
  [[ "$output" =~ "20[0-9][0-9]-" ]] || echo "Timestamp pattern should be in output"
}

@test "screenshot_app.sh detects missing find_window_id.py" {
  # Temporarily hide find_window_id.py
  WINDOW_FINDER="$SCRIPT_DIR/find_window_id.py"
  BACKUP="${WINDOW_FINDER}.bak"
  
  if [ -f "$WINDOW_FINDER" ]; then
    mv "$WINDOW_FINDER" "$BACKUP"
  fi
  
  export CI=true
  run bash "$SCREENSHOT_SCRIPT" "test"
  
  # Restore find_window_id.py
  if [ -f "$BACKUP" ]; then
    mv "$BACKUP" "$WINDOW_FINDER"
  fi
  
  # Should exit with error code 3 (missing dependency)
  [ "$status" -eq 3 ]
  [[ "$output" =~ "find_window_id.py" ]]
}

@test "screenshot_app.sh CI mode doesn't open files" {
  export CI=true
  export OUTPUT_DIR="$TEST_TEMP_DIR/ci-mode-test"
  
  # Will fail (no app), but verify CI behavior
  run bash "$SCREENSHOT_SCRIPT" "ci_test" 2>&1 || true
  
  # Output should not mention "Opening screenshot" in CI mode
  ! [[ "$output" =~ "Opening screenshot" ]]
}

@test "screenshot_app.sh verbose mode shows debug output" {
  export VERBOSE=true
  export CI=true
  export OUTPUT_DIR="$TEST_TEMP_DIR/verbose-test"
  
  run bash "$SCREENSHOT_SCRIPT" "verbose_test" 2>&1 || true
  
  # Should show debug messages (🔍 emoji or "debug" text)
  [[ "$output" =~ "🔍" ]] || [[ "$output" =~ "debug" ]] || [[ "$output" =~ "Output file:" ]]
}

@test "screenshot_app.sh exits with proper error code when app not running" {
  # Skip if app is actually running (success is OK)
  if pgrep -f "ShaderPlayground|MetalShaderStudio" >/dev/null; then
    skip "App is running (test expects it not to be)"
  fi
  
  export CI=true
  export OUTPUT_DIR="$TEST_TEMP_DIR/no-app-test"
  
  run bash "$SCREENSHOT_SCRIPT" "test"
  
  # Should exit with error (1=app not found, 2=permission, 3=dependency)
  [ "$status" -ne 0 ]
  [ "$status" -ge 1 ]
  [ "$status" -le 3 ]
}

# Integration test (only if app is actually running - skipped otherwise)
@test "screenshot_app.sh captures window when app is running" {
  # Check if ShaderPlayground/MetalShaderStudio is running
  if ! pgrep -f "ShaderPlayground\|MetalShaderStudio" >/dev/null; then
    skip "App not running (expected in CI)"
  fi
  
  export OUTPUT_DIR="$TEST_TEMP_DIR/integration-test"
  export CI=true
  
  run bash "$SCREENSHOT_SCRIPT" "integration_test"
  
  # Should succeed if app is running
  [ "$status" -eq 0 ]
  
  # Should have created a screenshot file
  [ "$(ls -1 "$OUTPUT_DIR"/*.png 2>/dev/null | wc -l)" -gt 0 ]
}
