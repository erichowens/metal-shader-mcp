# Visual Regression Testing Guide

## Overview

This document describes the visual regression testing framework for Metal Shader MCP. Visual tests ensure that shader rendering remains consistent across code changes, catching unintended visual regressions early.

## Quick Start

### Running Tests

```bash
# Run all tests (including visual regression)
swift test

# Run only visual regression tests
swift test --filter VisualRegressionTests

# Run with custom resolution
VIS_RES_W=256 VIS_RES_H=256 swift test --filter VisualRegressionTests

# Run with relaxed tolerance (debugging)
VIS_TOL_GLOBAL=10 swift test --filter VisualRegressionTests
```

### When Tests Fail

1. **Check the failure output** - Tests report mismatch counts and save debug artifacts
2. **Review saved images** in `Resources/screenshots/tests/`:
   - `actual_*.png` - What was actually rendered
   - `diff_*.png` - Pixels that differ highlighted in red
   - `heatmap_*.png` - Intensity map of differences (brighter = more difference)
   - `*_summary_*.json` - Test metadata including tolerance used
3. **Determine if change is expected**:
   - If visual change is intentional → Update goldens (see below)
   - If change is a regression → Fix the shader/rendering code

### Updating Golden Images

When you make intentional visual changes:

```bash
# 1. Run tests to generate new actual images
swift test --filter VisualRegressionTests

# 2. Review actual images in Resources/screenshots/tests/
# 3. If they look correct, copy to test fixtures
cp Resources/screenshots/tests/actual_*.png Tests/MetalShaderTests/Fixtures/

# 4. Rename to match golden naming convention
cd Tests/MetalShaderTests/Fixtures/
mv actual_constant_color_64x64.png golden_constant_color_64x64.png

# 5. Regenerate test bundle
make regen-goldens

# 6. Verify tests now pass
swift test --filter VisualRegressionTests
```

## Architecture

### Test Structure

```
Tests/MetalShaderTests/
├── VisualRegressionTests.swift          # Constant color test (golden image comparison)
├── VisualRegressionGradientTests.swift  # Gradient test (computed expectation)
├── GoldenImageIntegrityTests.swift      # Validates golden images exist and are valid
├── TestImageUtils.swift                 # PNG I/O, comparison, tolerance resolution
└── Fixtures/                            # Golden images embedded in test bundle
    └── golden_*.png
```

### Tolerance Configuration

Tolerance values specify maximum allowed color difference per channel (0-255).

**Precedence**: `byTest` > `byResolution` > `default` > Environment Variables override all

**Configuration File**: `Resources/communication/visual_test_config.json`

```json
{
  "default": {
    "global": 2,   // Fallback tolerance for all channels
    "r": 2,        // Red channel tolerance
    "g": 2,        // Green channel tolerance  
    "b": 2,        // Blue channel tolerance
    "a": 0         // Alpha channel (typically exact match)
  },
  "byResolution": {
    "64x64": { "global": 2 },
    "256x256": { "global": 4 }
  },
  "byTest": {
    "VisualRegressionTests.testConstantColorImageMatchesGoldenWithinTolerance": {
      "global": 2
    }
  }
}
```

### Environment Variables

Override tolerance values at runtime:

```bash
# Override global tolerance
VIS_TOL_GLOBAL=5 swift test

# Override per-channel
VIS_TOL_R=3 VIS_TOL_G=3 VIS_TOL_B=3 swift test

# Override test resolution
VIS_RES_W=512 VIS_RES_H=512 swift test
```

## Test Types

### 1. Golden Image Comparison

**Example**: `VisualRegressionTests.testConstantColorImageMatchesGoldenWithinTolerance`

**How it works**:
1. Renders a shader to a texture
2. Reads back pixel data as BGRA8
3. Loads golden PNG from test bundle
4. Compares pixel-by-pixel within tolerance
5. On failure, saves actual, diff, and heatmap images

**Best for**: Simple, deterministic shaders with known output

**Tolerance strategy**: Strict (2-4 per channel)

### 2. Computed Expectation

**Example**: `VisualRegressionGradientTests.testGradientMatchesGoldenWithinTolerance`

**How it works**:
1. Renders gradient shader
2. Computes expected pixel values mathematically
3. Compares rendered output to computed expectation
4. Tries multiple UV coordinate interpretations to handle ambiguity
5. On failure, saves actual and heatmap

**Best for**: Gradients, procedural content, cross-platform consistency

**Tolerance strategy**: Relaxed (8-16 per channel) to account for GPU interpolation variance

### 3. Golden Image Integrity

**Tests**: `GoldenImageIntegrityTests.swift`

**What it checks**:
- All expected golden images exist in test bundle
- Golden images are valid PNGs
- Dimensions match expectations
- Pixel format is BGRA8
- Tolerance configuration is valid JSON

**Runs before**: Visual regression tests to catch setup issues early

## Debugging Failed Tests

### Common Failure Modes

#### 1. Color Space Mismatch
**Symptoms**: Slight color shifts (1-3 values per channel)
**Solution**: 
- Use computed expectations instead of golden PNGs
- Increase tolerance slightly (3-5)
- Ensure consistent color space in golden generation

#### 2. GPU Interpolation Variance
**Symptoms**: Edge pixels differ, gradient bands shift
**Solution**:
- Increase tolerance for gradient tests (10-16)
- Use computed expectations
- Test on multiple GPUs to find reasonable tolerance

#### 3. Resolution Issues
**Symptoms**: Entire image fails, dimension errors
**Solution**:
- Check `VIS_RES_W` and `VIS_RES_H` environment variables
- Ensure golden images exist for target resolution
- Generate resolution-specific goldens if needed

#### 4. Missing Golden Images
**Symptoms**: Test fails immediately with "Missing golden image"
**Solution**:
- Run `GoldenImageIntegrityTests` first
- Generate golden image from actual output
- Run `make regen-goldens`

### Debug Workflow

```bash
# 1. Run failing test with debug output
swift test --filter YourFailingTest 2>&1 | tee test_output.txt

# 2. Check summary JSON for tolerance info
cat Resources/screenshots/tests/*_summary_*.json

# 3. Open images side-by-side
open Resources/screenshots/tests/actual_*.png
open Resources/screenshots/tests/diff_*.png
open Resources/screenshots/tests/heatmap_*.png

# 4. Analyze heatmap - brighter areas = more difference
# Red channel intensity shows pixel delta magnitude

# 5. If difference is acceptable, adjust tolerance
# Edit Resources/communication/visual_test_config.json

# 6. Or update golden if change is intentional
cp Resources/screenshots/tests/actual_*.png Tests/MetalShaderTests/Fixtures/golden_*.png
make regen-goldens
```

## Best Practices

### Creating New Visual Tests

1. **Start with golden image comparison** for simple, deterministic output
2. **Use computed expectation** for gradients or procedural content
3. **Choose appropriate tolerance**:
   - Constant colors: 2-4
   - Simple gradients: 8-12
   - Complex gradients: 12-16
   - Never above 20 (too permissive)
4. **Test multiple resolutions** (64x64, 128x128, 256x256)
5. **Document test rationale** in test method comments

### Maintaining Golden Images

1. **Version control goldens** - Commit to git
2. **Review changes carefully** - Visual regressions are subtle
3. **Test on multiple machines** before updating goldens
4. **Document major visual changes** in CHANGELOG.md
5. **Keep resolution-specific goldens** if rendering varies by size

### Tolerance Configuration

1. **Start strict** (tolerance=2) and relax only if needed
2. **Document rationale** in config JSON (_rationale field)
3. **Use per-test tolerance** for problematic shaders
4. **Prefer per-channel** over global tolerance when possible
5. **Never disable tests** with tolerance=255

### CI/CD Integration

```yaml
# Example GitHub Actions workflow
- name: Run Visual Tests
  run: swift test --filter VisualRegressionTests
  
- name: Upload Failure Artifacts
  if: failure()
  uses: actions/upload-artifact@v3
  with:
    name: visual-test-failures
    path: Resources/screenshots/tests/
```

## Performance Considerations

- **Golden PNG I/O**: ~10-20ms per 256x256 image
- **Pixel comparison**: ~1-2ms per 256x256 image
- **Metal shader compilation**: ~50-200ms (cached after first run)
- **GPU rendering**: <1ms for simple shaders

**Optimization tips**:
- Use smaller test resolutions (64x64) for speed
- Share Metal device/queue across tests
- Cache compiled shaders when possible
- Run visual tests separately from unit tests

## Troubleshooting

### Tests Pass Locally But Fail in CI

**Likely causes**:
- Different GPU hardware
- Different macOS version
- Different Metal driver version
- Color space configuration differences

**Solutions**:
- Increase tolerance for CI environment
- Use computed expectations instead of goldens
- Generate CI-specific goldens
- Document known GPU-specific differences

### Tests Are Flaky

**Likely causes**:
- Tolerance too strict for GPU variance
- Non-deterministic shader (e.g., using time/random)
- Resolution conflicts
- Race conditions in rendering pipeline

**Solutions**:
- Increase tolerance gradually
- Remove non-deterministic elements from test shaders
- Explicitly set resolution with environment variables
- Add synchronization (cb.waitUntilCompleted())

### Cannot Update Goldens

**Likely causes**:
- Bundle.module path incorrect
- Fixtures directory not in test target
- File permissions issue

**Solutions**:
```bash
# Verify test target includes Fixtures
swift package describe --type json | jq '.targets[] | select(.name=="MetalShaderTests") | .resources'

# Manually copy and rebuild
cp Resources/screenshots/tests/actual_*.png Tests/MetalShaderTests/Fixtures/
swift package clean
swift build --target MetalShaderTests
```

## Advanced Topics

### Custom Comparison Metrics

Beyond per-pixel tolerance, you can implement:
- **SSIM (Structural Similarity Index)**: Perceptual similarity
- **MSE (Mean Squared Error)**: Average pixel difference
- **Histogram comparison**: Color distribution matching
- **Edge detection**: Structural preservation

See `TestImageUtils.swift` for implementation examples.

### Multi-Platform Testing

Test across different Apple platforms:

```swift
#if os(macOS)
let device = MTLCreateSystemDefaultDevice()
#elseif os(iOS)
let device = MTLCreateSystemDefaultDevice() 
#endif

// Adjust tolerance by platform if needed
let tolerance = ProcessInfo.processInfo.environment["PLATFORM"] == "iOS" ? 4 : 2
```

### Performance Profiling

Profile visual tests to identify bottlenecks:

```bash
# Measure with Instruments
xcrun xctrace record --template Time --target MetalShaderTests --launch -- test

# Analyze shader compilation time
METAL_DEVICE_WRAPPER_TYPE=1 swift test --filter VisualRegressionTests
```

## References

- [Metal Programming Guide](https://developer.apple.com/metal/)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Color Space Best Practices](https://developer.apple.com/documentation/coregraphics/cgcolorspace)
- [Visual Testing Patterns](https://martinfowler.com/bliki/VisualTesting.html)

## Changelog

- **2025-10-19**: Initial version with tolerance documentation and debugging guide
- **2025-10-26**: Added golden image integrity tests and CI integration examples

---

**Maintained by**: Metal Shader MCP Team  
**Last Updated**: 2025-10-19
