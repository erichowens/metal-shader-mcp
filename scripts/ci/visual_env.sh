#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Visual Testing Environment Setup for CI
# Validates and configures macOS runners for visual testing
#
# Usage: bash scripts/ci/visual_env.sh
#
# Exit Codes:
#   0 - Environment ready
#   1 - Non-fatal warning (continues)
#   2 - Fatal error (cannot proceed)

# Logging
log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*" >&2; }
log_error() { echo "❌ $*" >&2; }
log_section() { echo ""; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; echo "📦 $*"; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }

EXIT_CODE=0

# Detect CI environment
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  log_info "Running in GitHub Actions"
  export CI=true
else
  log_info "Running locally"
  export CI=false
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_section "System Information"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log_info "macOS version:"
sw_vers

log_info "Hardware:"
sysctl -n machdep.cpu.brand_string
sysctl -n hw.memsize | awk '{print "RAM: " $1/1073741824 " GB"}'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_section "Metal Support Check"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if command -v xcrun &>/dev/null; then
  log_success "Found: xcrun"
  
  # Check Metal compiler
  if xcrun -sdk macosx -f metal &>/dev/null; then
    METAL_VERSION=$(xcrun -sdk macosx metal --version 2>&1 | head -1 || echo "unknown")
    log_success "Metal compiler: $METAL_VERSION"
  else
    log_error "Metal compiler not found"
    EXIT_CODE=2
  fi
  
  # Check for Metal-capable GPU
  if system_profiler SPDisplaysDataType 2>/dev/null | grep -qi "Metal"; then
    GPU_INFO=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -A3 "Chipset Model" | head -4 || echo "unknown")
    log_success "Metal-capable GPU detected"
    echo "$GPU_INFO" | sed 's/^/    /'
  else
    log_warn "Could not verify Metal GPU support"
    EXIT_CODE=1
  fi
else
  log_error "xcrun not found - Xcode Command Line Tools required"
  EXIT_CODE=2
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_section "Toolchain Validation"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check required commands
REQUIRED_CMDS=(swift xcodebuild python3 screencapture osascript)
for cmd in "${REQUIRED_CMDS[@]}"; do
  if command -v "$cmd" &>/dev/null; then
    VERSION=$("$cmd" --version 2>&1 | head -1 || echo "")
    log_success "Found: $cmd ${VERSION:0:50}"
  else
    log_error "Missing required command: $cmd"
    EXIT_CODE=2
  fi
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_section "Dependency Installation"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Homebrew setup
if ! command -v brew &>/dev/null; then
  log_warn "Homebrew not found, skipping optional dependencies"
else
  log_success "Found: brew $(brew --version | head -1)"
  
  # Update brew in CI to get latest formulae
  if [[ "$CI" == "true" ]]; then
    log_info "Updating Homebrew (CI mode)..."
    brew update --quiet || log_warn "brew update failed (non-fatal)"
  fi
  
  # Install jq (useful but optional)
  if ! command -v jq &>/dev/null; then
    log_info "Installing jq..."
    if brew install jq --quiet 2>/dev/null; then
      log_success "Installed: jq"
    else
      log_warn "Could not install jq (non-fatal, will use grep fallback)"
    fi
  else
    log_success "Found: jq $(jq --version 2>&1 || echo '')"
  fi
  
  # Install bats-core for script testing
  if ! command -v bats &>/dev/null; then
    log_info "Installing bats-core..."
    if brew install bats-core --quiet 2>/dev/null; then
      log_success "Installed: bats"
    else
      log_warn "Could not install bats (non-fatal)"
    fi
  else
    log_success "Found: bats $(bats --version 2>&1 | head -1 || echo '')"
  fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_section "macOS UI Configuration"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [[ "$CI" == "true" ]]; then
  log_info "Disabling window animations for consistent captures..."
  defaults write -g NSAutomaticWindowAnimationsEnabled -bool false || log_warn "Could not disable animations"
  
  log_info "Setting reduced motion..."
  defaults write com.apple.Accessibility ReduceMotionEnabled -bool true || log_warn "Could not set reduced motion"
  
  log_success "macOS UI configured for CI"
else
  log_info "Skipping UI config (local mode)"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_section "Screenshot Capability Test"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Run screenshot self-test if available
SCREENSHOT_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/screenshot_app.sh"
if [[ -x "$SCREENSHOT_SCRIPT" ]]; then
  log_info "Running screenshot self-test..."
  if bash "$SCREENSHOT_SCRIPT" --self-test; then
    log_success "Screenshot capability verified"
  else
    SELF_TEST_EXIT=$?
    log_error "Screenshot self-test failed (exit code: $SELF_TEST_EXIT)"
    EXIT_CODE=2
    
    # Preserve self-test artifacts for debugging
    SELFTEST_ARTIFACT="${TMPDIR:-/tmp}/screenshot-selftest-*.png"
    if compgen -G "$SELFTEST_ARTIFACT" > /dev/null 2>&1; then
      log_info "Self-test artifacts available: $SELFTEST_ARTIFACT"
      # In CI, we'll upload these as artifacts via workflow
    fi
  fi
else
  log_warn "screenshot_app.sh not found or not executable: $SCREENSHOT_SCRIPT"
  EXIT_CODE=1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_section "Environment Variables"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Export CI-friendly defaults for screenshot scripts
export CI=true
export OUTPUT_DIR="${OUTPUT_DIR:-Resources/screenshots}"
export VERBOSE="${VERBOSE:-false}"

log_info "CI-friendly defaults set:"
echo "  CI=$CI"
echo "  OUTPUT_DIR=$OUTPUT_DIR"
echo "  VERBOSE=$VERBOSE"

# Make exports available to subsequent steps in GitHub Actions
if [[ "${GITHUB_ENV:-}" != "" ]]; then
  echo "CI=true" >> "$GITHUB_ENV"
  echo "OUTPUT_DIR=$OUTPUT_DIR" >> "$GITHUB_ENV"
  log_success "Variables exported to GITHUB_ENV"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_section "Summary"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  log_success "✨ Visual testing environment ready!"
  echo ""
  echo "Next steps:"
  echo "  • swift build"
  echo "  • swift test --filter VisualRegression"
  echo "  • bash scripts/screenshot_app.sh --self-test"
  echo ""
elif [[ $EXIT_CODE -eq 1 ]]; then
  log_warn "⚠️  Environment has warnings but may work"
  echo ""
  echo "Consider addressing warnings before running tests"
  echo ""
else
  log_error "❌ Environment is not ready for visual testing"
  echo ""
  echo "Fix critical errors before proceeding"
  echo ""
fi

exit $EXIT_CODE
