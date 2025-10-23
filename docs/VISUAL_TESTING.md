# Visual Testing Documentation

**Status**: Production-grade visual testing system for macOS SwiftUI + Metal applications  
**Last Updated**: 2025-10-13  
**Supported Platforms**: macOS 14/15 with Xcode 15/16 and Metal-capable GPU

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Dependencies](#dependencies)
- [Running Tests Locally](#running-tests-locally)
- [Screenshot Capture](#screenshot-capture)
- [CI Integration](#ci-integration)
- [Test Suites](#test-suites)
- [Updating Golden Images](#updating-golden-images)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Secrets and Authentication](#secrets-and-authentication)

---

## Overview

The Metal Shader MCP project includes a comprehensive visual testing system that:

- **Captures screenshots** of the Metal Shader Studio app for visual verification
- **Compares renders** against golden reference images
- **Runs in CI** with automated artifact collection
- **Supports local iteration** with fast feedback loops
- **Provides resilient window detection** with retry logic and multiple strategies

### What Works Today

✅ Automated screenshot capture via `screenshot_app.sh`  
✅ Swift-based visual regression tests with pixel-perfect comparison  
✅ CI integration with GitHub Actions (PR and nightly workflows)  
✅ Golden image management with documented update process  
✅ Comprehensive troubleshooting and error recovery  
✅ Background app launch to avoid stealing focus  
✅ Cross-resolution testing matrix (nightly)

---

## Quick Start

```bash
# 1. Install dependencies
brew install jq python@3.12 bats-core

# 2. Build the project
swift build

# 3. Run all tests
swift test

# 4. Run only visual regression tests
swift test --filter VisualRegression

# 5. Capture a screenshot manually
./scripts/screenshot_app.sh "test_feature_description"
```

---

## Dependencies

### System Requirements

- **macOS**: 14 (Sonoma) or 15 (Sequoia)
- **Xcode**: 15.x or 16.x with Command Line Tools
- **Metal**: GPU with Metal support (check with `system_profiler SPDisplaysDataType | grep -i Metal`)
- **Swift**: System swift installation (check with `swift --version`)

### Tool Dependencies

Install via Homebrew:

```bash
brew install jq python@3.12 bats-core
```

**Required System Tools** (pre-installed on macOS):
- `screencapture` - Native macOS screenshot utility
- `osascript` - AppleScript execution
- `xcrun` - Xcode toolchain access
- `xcodebuild` - Project building

### Python Dependencies

The `find_window_id.py` script uses only Python standard library modules:
- `subprocess`, `json`, `sys`, `os`, `time`, `argparse`, `typing`

No `pip install` required! ✅

### TCC Permissions

On first run, macOS will request **Screen Recording** permission. This is required for `screencapture` to work.

**Grant permission**:
1. System Settings → Privacy & Security → Screen Recording
2. Enable permission for Terminal (or your shell app)
3. Restart the terminal application

---

## Running Tests Locally

### All Tests

```bash
swift test
```

### Visual Tests Only

```bash
swift test --filter VisualRegression
```

This runs:
- `VisualRegressionTests.swift` - Core shader rendering tests
- `VisualRegressionGradientTests.swift` - Gradient-specific tests

### Test Output

On success:
```
Test Suite 'All tests' passed
     33 tests passed
```

On failure:
```
❌ Test failed: testPlasmaShaderRenders
Actual output: Resources/screenshots/tests/actual/plasma_shader.png
Expected (golden): Tests/MetalShaderTests/Fixtures/plasma_shader.png
Diff saved: Resources/screenshots/tests/diffs/plasma_shader.png
```

### Inspecting Test Results

Failed tests save artifacts to:
- **Actual renders**: `Resources/screenshots/tests/actual/`
- **Diff images**: `Resources/screenshots/tests/diffs/`
- **Golden images**: `Tests/MetalShaderTests/Fixtures/`

**Compare visually**:
```bash
open Resources/screenshots/tests/diffs/plasma_shader.png
```

---

## Screenshot Capture

### Basic Usage

The `screenshot_app.sh` script captures screenshots with consistent naming and metadata.

```bash
# Capture with default settings
./scripts/screenshot_app.sh "feature_description"

# Capture with custom app name
APP_NAME="MetalShaderStudio" ./scripts/screenshot_app.sh "test_case"

# Capture with bundle ID (more reliable)
APP_BUNDLE_ID="com.example.MetalShaderStudio" ./scripts/screenshot_app.sh "ui_state"

# Capture specific window by title
WINDOW_TITLE="Shader Playground" ./scripts/screenshot_app.sh "window_capture"
```

### Configuration via Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_NAME` | Application name to find | `MetalShaderStudio` |
| `APP_BUNDLE_ID` | Bundle identifier (preferred) | - |
| `APP_PATH` | Full path to .app bundle | - |
| `WINDOW_TITLE` | Specific window title to capture | - |
| `OUTPUT_DIR` | Where to save screenshots | `Resources/screenshots` |
| `SCREENSHOT_NAME` | Custom filename (without extension) | Auto-generated timestamp |
| `DELAY` | Seconds to wait before capture | `2` |
| `TIMEOUT` | Max seconds to wait for window | `30` |
| `RETRIES` | Max retry attempts for window detection | `10` |
| `RETRY_SLEEP` | Seconds between retries | `0.5` |
| `CAPTURE_MODE` | `window`, `display`, or `rect` | `window` |
| `ACTIVATE_APP` | Bring app to foreground | `true` (local), `false` (CI) |
| `CI` | CI environment detection | Auto-detected |
| `VERBOSE` | Enable detailed logging | `false` |

### Screenshot Naming Convention

```
YYYY-MM-DD_HH-MM-SS_description.png
```

Examples:
- `2025-10-13_09-15-30_plasma_shader_initial_render.png`
- `2025-10-13_09-16-45_ui_parameter_panel_expanded.png`

### Advanced Usage

**Help and self-test**:
```bash
# Show usage documentation
./scripts/screenshot_app.sh --help

# Validate environment without launching app
./scripts/screenshot_app.sh --self-test
```

**Background launch** (doesn't steal focus):
```bash
ACTIVATE_APP=false ./scripts/screenshot_app.sh "background_test"
```

**Custom timeout and retries**:
```bash
TIMEOUT=60 RETRIES=20 ./scripts/screenshot_app.sh "slow_startup"
```

**Dry run** (show what would be captured):
```bash
DRY_RUN=true ./scripts/screenshot_app.sh "test"
```

---

## `find_window_id.py` - Window Detection

The `find_window_id.py` script is the foundation of reliable screenshot capture. It uses Swift/CoreGraphics to enumerate windows and find the target application.

### Features

✅ **Retries with exponential backoff** - Waits for app to initialize  
✅ **Multiple search criteria** - Bundle ID, app name, or window title  
✅ **Selection strategies** - Choose frontmost, largest, or first match  
✅ **JSON output** - Structured output for scripting  
✅ **Proper exit codes** - 0=success, 2=not found, 3=ambiguous, 4=dependency error  
✅ **Environment configuration** - Tune retry behavior via env vars

### Usage Examples

```bash
# Find by app name (default behavior)
python3 scripts/find_window_id.py --app-name MetalShaderStudio

# Find by bundle ID (most reliable)
python3 scripts/find_window_id.py --bundle-id com.example.MyApp

# Find by window title
python3 scripts/find_window_id.py --window-title "Shader Playground"

# JSON output for scripting
python3 scripts/find_window_id.py --app-name MyApp --json

# Custom retry settings
python3 scripts/find_window_id.py --app-name MyApp --max-retries 20 --retry-delay 1.0

# Quiet mode (no stderr)
python3 scripts/find_window_id.py --app-name MyApp --quiet

# Use largest window when multiple matches
python3 scripts/find_window_id.py --app-name MyApp --strategy largest
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FIND_WINDOW_MAX_RETRIES` | Max retry attempts | `10` |
| `FIND_WINDOW_RETRY_DELAY` | Initial delay between retries (seconds) | `0.5` |
| `FIND_WINDOW_BACKOFF` | Backoff multiplier for exponential backoff | `1.5` |

### Exit Codes

- **0**: Success - window ID found and printed to stdout
- **2**: No window found after all retries
- **3**: Multiple ambiguous windows found (not currently used, reserved for future)
- **4**: Dependency error (swift not found or other tool missing)

### JSON Output Format

```json
{
  "windowID": 12345,
  "ownerName": "MetalShaderStudio",
  "windowName": "Shader Playground",
  "width": 1280,
  "height": 720,
  "x": 100,
  "y": 200,
  "layer": 0
}
```

### Selection Strategies

When multiple windows match, the strategy determines which to select:

- **`frontmost`** (default): Window with lowest layer number (closest to user)
- **`largest`**: Window with the largest area (width × height)
- **`first`**: First matching window found

### Integration with screenshot_app.sh

The screenshot script automatically uses `find_window_id.py` with appropriate retry settings. You can tune the behavior via environment variables:

```bash
FIND_WINDOW_MAX_RETRIES=20 FIND_WINDOW_RETRY_DELAY=1.0 ./scripts/screenshot_app.sh "test"
```

---

## CI Integration

### GitHub Actions Workflows

The project includes three visual testing workflows:

1. **`visual-tests.yml`** - Runs on PR and push to main
2. **`visual-nightly.yml`** - Scheduled nightly multi-resolution testing
3. **`ui-smoke.yml`** - Fast UI sanity check

### `visual-tests.yml` - PR/Push Workflow

**Triggers**: Push to `main`, pull requests  
**Runners**: `macos-15`, `macos-latest` matrix  
**Concurrency**: Cancels in-progress runs for same ref

**Steps**:
1. Checkout code
2. Run `scripts/ci/visual_env.sh` - Setup environment
3. `swift build` - Build project
4. `swift test --filter VisualRegression` - Run visual tests
5. `bats scripts/tests/*.bats` - Run script tests
6. Upload artifacts (screenshots, logs, test results)

**Artifacts** (uploaded on success or failure):
- `visual-test-results-<os>-<runner>` - Test outputs and screenshots
- Retention: 7 days

### `visual-nightly.yml` - Nightly Testing

**Triggers**: Scheduled at 02:00 UTC daily, manual dispatch  
**Runners**: `macos-latest`  
**Matrix**: Multiple window sizes (1280x720, 1920x1080, 2560x1440)

**Purpose**: Catch cross-resolution rendering issues and environmental drift

### `ui-smoke.yml` - Fast Sanity Check

**Triggers**: Push to `main`, pull requests  
**Runners**: `macos-latest`

**Purpose**: Quick UI health check (single screenshot capture)

### CI Environment Setup

The `scripts/ci/visual_env.sh` script prepares the CI runner:

```bash
#!/bin/bash
# Run once per CI job

# Print system info
sw_vers
system_profiler SPDisplaysDataType | grep -i Metal

# Install dependencies
brew install jq python@3.12 bats-core

# Disable animations
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false

# Export CI-friendly defaults
export CI=true
export ACTIVATE_APP=false
export VERBOSE=true
```

### Viewing CI Artifacts

1. Navigate to the GitHub Actions run
2. Scroll to **Artifacts** section at the bottom
3. Download `visual-test-results-<os>-<runner>.zip`
4. Extract and inspect screenshots, logs, and test outputs

### CI Screenshot Capture Strategy

In CI environments, the script:
- Launches app in background (`open -g` for macOS)
- Uses retries with longer timeout (60s default)
- Falls back to full-screen capture if window capture fails
- Always uploads artifacts even on failure (`if: always()`)

---

## Test Suites

### VisualRegressionTests.swift

Core shader rendering tests with pixel-perfect comparison against golden images.

**Test Cases**:
- `testPlasmaShaderRenders` - Verifies plasma shader output
- `testNoiseShaderRenders` - Verifies noise shader output
- `testRipplesShaderRenders` - Verifies ripples shader output
- _(Add more as shaders are developed)_

**Test Structure**:
```swift
func testPlasmaShaderRenders() throws {
    let shader = PlasmaShader()
    let output = try renderShader(shader, width: 512, height: 512)
    
    let golden = loadGoldenImage("plasma_shader.png")
    XCTAssertImagesEqual(output, golden, tolerance: 0.02)
}
```

**Tolerance**: Visual tests use a tolerance threshold (default 2%) to account for:
- Minor GPU driver differences
- Color space conversions
- Floating-point precision variations

Configure via environment:
```bash
VISUAL_TEST_TOLERANCE=0.05 swift test --filter VisualRegression
```

### VisualRegressionGradientTests.swift

Specialized tests for gradient rendering with deterministic inputs.

**Deterministic Rendering**:
- Fixed random seeds for reproducible noise
- Consistent frame sizes (512×512, 1024×1024)
- sRGB color space enforcement
- Double-precision time values

**Test Cases**:
- `testLinearGradient` - Simple gradient progression
- `testRadialGradient` - Radial gradient rendering
- `testAnimatedGradient` - Time-based gradient animation (fixed seed)

---

## Updating Golden Images

Golden images are the reference images that tests compare against. When shader code changes intentionally, goldens must be updated.

### When to Update Goldens

✅ **Intentional visual changes**: New shader features, parameter adjustments, bugfixes  
✅ **Golden file corruption**: File damaged or missing  
✅ **Platform updates**: Major OS or GPU driver changes requiring baseline refresh  

❌ **DO NOT update goldens to make failing tests pass without understanding why they failed**

### Update Process

```bash
# 1. Regenerate all golden images
make regen-goldens

# 2. Review the changes visually
open Tests/MetalShaderTests/Fixtures/*.png

# 3. Run tests to verify new goldens
swift test --filter VisualRegression

# 4. Commit the new goldens
git add Tests/MetalShaderTests/Fixtures/
git commit -m "chore: update visual regression goldens for [reason]"
```

### Golden Image Locations

Golden images are stored in the test bundle:
```
Tests/MetalShaderTests/Fixtures/
├── plasma_shader.png
├── noise_shader.png
├── ripples_shader.png
├── linear_gradient.png
├── radial_gradient.png
└── animated_gradient.png
```

These are **bundle resources** and accessed via `Bundle.module` in tests.

### PR Review Checklist for Golden Updates

When reviewing a PR that updates goldens:

- [ ] **Visual evidence provided**: PR description includes before/after screenshots
- [ ] **Reason documented**: Clear explanation of why goldens changed
- [ ] **Tests pass**: All visual tests green with new goldens
- [ ] **Intentional change**: Change is deliberate, not accidental regression
- [ ] **Multiple reviewers**: At least one other person verifies visual output
- [ ] **CHANGELOG updated**: Change noted in CHANGELOG.md

---

## Troubleshooting

### Screen Recording Permission Denied

**Symptoms**: `screencapture` fails with permission error, no screenshot generated

**Solution**:
```bash
# 1. Open System Settings
# 2. Privacy & Security → Screen Recording
# 3. Enable for Terminal (or your shell app)
# 4. Restart terminal completely
```

**Verify permission**:
```bash
./scripts/screenshot_app.sh --self-test
```

### Window Not Found

**Symptoms**: `find_window_id.py` exits with code 2, logs "No window found"

**Possible Causes**:
- App not running or still launching
- App name/bundle ID incorrect
- Window is hidden or minimized
- TCC permissions blocking window enumeration

**Debugging**:
```bash
# 1. Verify app is running
ps aux | grep MetalShaderStudio

# 2. List all windows manually
python3 scripts/find_window_id.py --app-name "" --json

# 3. Try with increased retries
python3 scripts/find_window_id.py --app-name MetalShaderStudio --max-retries 30 --retry-delay 2.0
```

### Multiple Windows Found

**Symptoms**: Script finds multiple matching windows, unclear which to capture

**Solution**: Use selection strategy or more specific criteria

```bash
# Use frontmost window (default)
python3 scripts/find_window_id.py --app-name MyApp --strategy frontmost

# Use largest window
python3 scripts/find_window_id.py --app-name MyApp --strategy largest

# Use bundle ID for more precision
python3 scripts/find_window_id.py --bundle-id com.example.MyApp
```

### Swift Not Found (Exit Code 4)

**Symptoms**: `find_window_id.py` exits with code 4, "swift command not found"

**Solution**:
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Verify installation
swift --version
```

### Metal Not Available in CI

**Symptoms**: Tests fail in CI with Metal device errors

**Solution**: Ensure runner has Metal support

```yaml
# .github/workflows/visual-tests.yml
jobs:
  test:
    runs-on: macos-latest  # ← Must be macOS runner
    steps:
      - name: Verify Metal
        run: |
          system_profiler SPDisplaysDataType | grep -i Metal
          # Exit if no Metal support
```

**Note**: GitHub-hosted `macos-*` runners have Metal support.

### Retina Scaling Issues

**Symptoms**: Screenshots appear at 2x or wrong resolution

**Explanation**: macOS Retina displays use HiDPI rendering. `screencapture` captures at native resolution.

**Solution**: Normalize in test comparisons or use fixed window sizes

```bash
# Set specific window size before capture
osascript -e 'tell application "System Events" to set size of window 1 of process "MyApp" to {1280, 720}'
```

### Color Profile Mismatches

**Symptoms**: Slight color differences in golden vs actual images

**Solution**: Enforce sRGB color space in Metal rendering

```swift
// In Metal shader rendering setup
let colorAttachment = renderPassDescriptor.colorAttachments[0]!
colorAttachment.texture = drawable.texture
// Force sRGB color space
let srgbTexture = drawable.texture // Ensure texture uses sRGB format
```

---

## Best Practices

### ✅ DO

- **Run visual tests locally** before pushing to avoid CI failures
- **Review visual diffs carefully** when tests fail
- **Document golden updates** with before/after screenshots in PRs
- **Use deterministic inputs** (fixed seeds, consistent frame sizes)
- **Keep goldens in version control** for traceability
- **Run tests in isolation** (`swift test --parallel`) to avoid race conditions

### ❌ DON'T

- **Update goldens without understanding failures** - Investigate root cause first
- **Commit screenshots to main** - Use `Resources/screenshots/` (gitignored)
- **Rely on visual tests alone** - Combine with unit tests for logic
- **Ignore tolerance adjustments** - Document why tolerance was increased
- **Run tests with UI animations enabled** - Disable for consistency

---

## Secrets and Authentication

### No Secrets Required ✅

The visual testing system **does not require any external API keys or secrets**.

- **GITHUB_TOKEN**: Auto-provided by GitHub Actions, no configuration needed
- **Third-party services**: Not used (no Percy, Chromatic, etc.)
- **Local credentials**: Not required

### `.env` Files

❌ **DO NOT create `.env` files for visual testing**  
✅ All configuration via environment variables or CI workflow inputs  

The `.env.example` file exists for other project components (e.g., API development), not for visual testing.

### Deployment

When deploying or running in new environments:
- No service keys to retrieve
- No credentials to configure
- No external accounts required

Just ensure:
- macOS with Metal GPU
- Xcode Command Line Tools
- TCC Screen Recording permission (if running interactively)

---

## Adding New Visual Tests

### 1. Write the Test

Add to `Tests/MetalShaderTests/VisualRegressionTests.swift`:

```swift
func testMyNewShaderRenders() throws {
    let shader = MyNewShader(parameter: 1.0)
    let output = try renderShader(shader, width: 512, height: 512, seed: 42)
    
    let golden = loadGoldenImage("my_new_shader.png")
    XCTAssertImagesEqual(output, golden, tolerance: 0.02)
}
```

### 2. Generate the Golden

```bash
# Run test once to generate actual output
swift test --filter testMyNewShaderRenders

# Copy actual to golden location
cp Resources/screenshots/tests/actual/my_new_shader.png \
   Tests/MetalShaderTests/Fixtures/my_new_shader.png
```

### 3. Verify

```bash
# Run test again - should now pass
swift test --filter testMyNewShaderRenders
```

### 4. Document

Update this file (`VISUAL_TESTING.md`) with:
- New test case in [Test Suites](#test-suites) section
- Any special considerations for the shader

---

## Quick Reference Commands

```bash
# Run all tests
swift test

# Run visual tests only
swift test --filter VisualRegression

# Capture screenshot
./scripts/screenshot_app.sh "description"

# Find window ID
python3 scripts/find_window_id.py --app-name MetalShaderStudio

# Self-test environment
./scripts/screenshot_app.sh --self-test

# Update goldens
make regen-goldens

# Clean test artifacts
rm -rf Resources/screenshots/tests/
```

---

## Support and Contributing

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Search existing GitHub issues
3. Open a new issue with:
   - System info (`sw_vers`, `swift --version`)
   - Metal support (`system_profiler SPDisplaysDataType | grep -i Metal`)
   - Screenshots/logs demonstrating the issue
   - Steps to reproduce

**Contributing**:
- PRs welcome for improved documentation, test coverage, or tooling
- Follow the [WARP.md](../WARP.md) workflow protocol
- Include visual evidence for shader/UI changes

---

**End of Visual Testing Documentation**  
For more context, see [WARP.md](../WARP.md) and [CHANGELOG.md](../CHANGELOG.md).
