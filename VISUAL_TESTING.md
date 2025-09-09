# Visual Testing Framework

## Overview

This document outlines the visual testing framework for the Metal Shader MCP project. Visual testing is critical for shader development as it ensures visual consistency, prevents regressions, and validates artistic intent.

## 🎯 Testing Philosophy

### Why Visual Testing Matters for Shaders
- **Shader Output is Visual**: The primary output of shader code is visual, not textual
- **Parameter Sensitivity**: Small parameter changes can dramatically alter visual output
- **Cross-Platform Consistency**: Shaders must render consistently across different devices
- **Artistic Intent Preservation**: Visual tests preserve the intended aesthetic as code evolves

## 📸 Screenshot Management

### Directory Structure
```
Resources/
├── screenshots/
│   ├── baselines/           # Reference images for comparison
│   ├── current/             # Latest test run screenshots
│   ├── diffs/              # Visual diff images
│   └── archive/            # Historical screenshots
```

### Naming Convention
```
YYYY-MM-DD_HH-MM-SS_<shader_name>_<test_type>_<parameters>.png
```
Notes:
- This convention is recommended for human readability and audit trails.
- CI does not enforce naming; the pipeline prioritizes speed and only reports counts.
- Automated visual regression thresholds are configurable and will be documented when the diff tool lands (default target: 0.95 similarity).

## 🧪 Test Types

### 1. Shader Render Tests
Capture standard renders of each shader with known parameter sets:

```swift
// Test structure example
func testPlasmaShaderBasicRender() {
    let shader = PlasmaShader()
    shader.frequency = 1.0
    shader.amplitude = 0.5
    shader.speed = 1.0
    
    let screenshot = captureShaderOutput(shader, size: CGSize(width: 512, height: 512))
    compareToBaseline(screenshot, name: "plasma_basic_default")
}
```

### 2. Parameter Variation Tests  
Document how parameter changes affect visual output:

```swift
func testPlasmaFrequencyVariations() {
    let shader = PlasmaShader()
    let frequencies = [0.5, 1.0, 2.0, 4.0]
    
    for freq in frequencies {
        shader.frequency = freq
        let screenshot = captureShaderOutput(shader, size: CGSize(width: 512, height: 512))
        compareToBaseline(screenshot, name: "plasma_frequency_\(freq)")
    }
}
```

### 3. UI Component Tests
Screenshot key UI states and interactions:

```swift
func testParameterPanelStates() {
    // Test collapsed state
    let collapsedUI = captureUI(component: parameterPanel, state: .collapsed)
    compareToBaseline(collapsedUI, name: "parameter_panel_collapsed")
    
    // Test expanded state  
    let expandedUI = captureUI(component: parameterPanel, state: .expanded)
    compareToBaseline(expandedUI, name: "parameter_panel_expanded")
}
```

### 4. Cross-Resolution Tests
Ensure shaders work across different display sizes:

```swift
func testShaderCrossResolution() {
    let shader = PlasmaShader()
    let resolutions = [
        CGSize(width: 256, height: 256),   // Small
        CGSize(width: 512, height: 512),   // Medium  
        CGSize(width: 1024, height: 1024), // Large
        CGSize(width: 1920, height: 1080)  // HD
    ]
    
    for size in resolutions {
        let screenshot = captureShaderOutput(shader, size: size)
        compareToBaseline(screenshot, name: "plasma_\(size.width)x\(size.height)")
    }
}
```

## 🛠 Implementation

### Core Visual Testing Infrastructure

```swift
// VisualTestingFramework.swift
class VisualTestingFramework {
    static let shared = VisualTestingFramework()
    
    private let baselineDirectory = "Resources/screenshots/baselines/"
    private let currentDirectory = "Resources/screenshots/current/"
    private let diffDirectory = "Resources/screenshots/diffs/"
    
    func captureShaderOutput(_ shader: Shader, size: CGSize) -> NSImage {
        // Render shader to texture
        // Convert texture to NSImage
        // Return captured image
    }
    
    func compareToBaseline(_ image: NSImage, name: String, threshold: Double = 0.95) -> Bool {
        guard let baseline = loadBaseline(name: name) else {
            // No baseline exists, save current as new baseline
            saveAsBaseline(image, name: name)
            return true
        }
        
        let similarity = calculateImageSimilarity(image, baseline)
        let passed = similarity >= threshold
        
        if !passed {
            generateDiffImage(current: image, baseline: baseline, name: name)
        }
        
        return passed
    }
    
    private func calculateImageSimilarity(_ image1: NSImage, _ image2: NSImage) -> Double {
        // Implement perceptual image comparison
        // Return similarity score (0.0 to 1.0)
    }
    
    private func generateDiffImage(current: NSImage, baseline: NSImage, name: String) {
        // Generate visual diff highlighting differences
        // Save to diffs directory
    }
}
```

### Integration with XCTest

```swift
// VisualRegressionTests.swift
import XCTest
@testable import MetalShaderStudio

class VisualRegressionTests: XCTestCase {
    let visualTesting = VisualTestingFramework.shared
    
    func testAllBasicShaders() {
        let shaders = ShaderLibrary.getAllShaders()
        
        for shader in shaders {
            let screenshot = visualTesting.captureShaderOutput(shader, size: CGSize(width: 512, height: 512))
            let passed = visualTesting.compareToBaseline(screenshot, name: "\(shader.name)_basic")
            
            XCTAssertTrue(passed, "Visual regression detected in \(shader.name)")
        }
    }
}
```

## 📝 Test Scripts

### Screenshot Capture
Use the working screenshot script:

```bash
#!/bin/bash
# Capture screenshots for visual testing

# Capture current app state
./scripts/screenshot_app.sh "shader_test_$(date +%Y%m%d_%H%M%S)"

# Debug window issues if needed
python3 scripts/debug_window.py

# Run Swift tests (when implemented)
swift test --filter VisualRegressionTests
```

### Visual Evidence Collection
The current system focuses on capturing visual evidence:

```bash
# Capture before making changes
./scripts/screenshot_app.sh "before_changes"

# Make your changes...

# Capture after changes
./scripts/screenshot_app.sh "after_changes"

# Compare manually or implement automated comparison later
```

## 🎨 Artistic Validation

### Visual Quality Metrics
Beyond pixel-perfect comparison, implement artistic quality metrics:

- **Color Harmony**: Analyze color palette consistency  
- **Composition Balance**: Evaluate visual weight distribution
- **Animation Smoothness**: Measure temporal consistency
- **Aesthetic Coherence**: Compare against artistic intent documentation

### Human Review Process
1. **Automated Filtering**: Only flag significant visual changes
2. **Artistic Review**: Human evaluation of flagged changes
3. **Intent Validation**: Confirm changes align with creative goals
4. **Baseline Updates**: Update references when changes are approved

## 🚀 Integration Workflow

### Pre-Commit Hooks
```bash
# .git/hooks/pre-commit
#!/bin/bash

echo "Running visual regression tests..."
swift test --filter VisualRegressionTests

if [ $? -ne 0 ]; then
    echo "Visual regression tests failed. Check screenshots in Resources/screenshots/diffs/"
    exit 1
fi

echo "Visual tests passed"
```

### CI/CD Integration
```yaml
# .github/workflows/visual-testing.yml
name: Visual Regression Testing

on: [push, pull_request]

jobs:
  visual-tests:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v2
    - name: Run Visual Tests
      run: swift test --filter VisualRegressionTests
    - name: Upload Screenshots
      uses: actions/upload-artifact@v2
      with:
        name: visual-test-results
        path: Resources/screenshots/
```

## 📊 Reporting

### Visual Test Report Generation
Generate HTML reports showing:
- Test results summary
- Side-by-side image comparisons  
- Diff highlights for failed tests
- Historical trends
- Performance metrics

### Dashboard Integration
Consider integration with:
- **GitHub Actions**: Automated PR checks
- **Slack/Discord**: Notification of test failures
- **Web Dashboard**: Real-time visual test status

## 🎯 Success Metrics

### Coverage Goals
- 100% of shaders have baseline render tests
- All UI components have visual tests
- Parameter variations documented for critical shaders
- Cross-resolution compatibility verified

### Quality Thresholds
- Default visual similarity threshold: 0.95 (configurable per-suite when diff tool lands)
- 100% test pass rate before deployment  
- 0 undocumented visual changes
- Visual test execution time budget: under 2 minutes in CI

---

*Visual testing transforms shader development from subjective evaluation to objective validation, ensuring that every pixel serves the artistic vision while maintaining technical excellence.*
