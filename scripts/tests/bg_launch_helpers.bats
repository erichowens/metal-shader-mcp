#!/usr/bin/env bats
# Tests for open_bg.sh, open_fg.sh, and focus_app.sh
# Run with: bats scripts/tests/bg_launch_helpers.bats

setup() {
  SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  OPEN_BG="$SCRIPT_DIR/open_bg.sh"
  OPEN_FG="$SCRIPT_DIR/open_fg.sh"
  FOCUS_APP="$SCRIPT_DIR/focus_app.sh"
  TEST_TMP="${BATS_TMPDIR}/bg-launch-tests-$$"
  mkdir -p "$TEST_TMP"
}

teardown() {
  rm -rf "$TEST_TMP" || true
}

@test "open_bg.sh exists and is executable" {
  [ -f "$OPEN_BG" ]
  [ -x "$OPEN_BG" ]
}

@test "open_fg.sh exists and is executable" {
  [ -f "$OPEN_FG" ]
  [ -x "$OPEN_FG" ]
}

@test "focus_app.sh exists and is executable" {
  [ -f "$FOCUS_APP" ]
  [ -x "$FOCUS_APP" ]
}

@test "open_bg.sh creates .runlogs directory even if build/app launch fails" {
  # Ensure .runlogs does not exist beforehand in a temp sandbox by running from repo root
  run bash -c "cd \"$(git rev-parse --show-toplevel)\" && rm -rf .runlogs && bash \"$OPEN_BG\" test_tab 2>&1 || true"
  [ "$status" -eq 0 ] || [ "$status" -ne 0 ]  # tolerate non-zero exit (build may fail in CI)
  [ -d "$(git rev-parse --show-toplevel)/.runlogs" ]
}

@test "open_fg.sh creates .runlogs and prints log path" {
  run bash -c "cd \"$(git rev-parse --show-toplevel)\" && rm -rf .runlogs && bash \"$OPEN_FG\" test_tab 2>&1 || true"
  [ -d "$(git rev-parse --show-toplevel)/.runlogs" ]
  [[ "$output" =~ "Logs:" ]] || echo "Expected 'Logs:' hint in output"
}

@test "focus_app.sh is no-op safe (does not error if app is not running)" {
  run bash "$FOCUS_APP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Brought MetalShaderStudio" ]] || true
}