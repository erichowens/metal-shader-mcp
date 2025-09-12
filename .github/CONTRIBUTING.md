# Contributing to Metal Shader MCP

Thank you for your interest in contributing to the Metal Shader MCP project! This guide will help you understand our development workflow and CI/CD pipeline.

## 🚀 Quick Start

1. **Fork and Clone**: Fork the repository and clone it locally
2. **Create Branch**: Create a feature branch from `main`
3. **Make Changes**: Implement your changes following our guidelines
4. **Test Locally**: Run workflows locally when possible
5. **Submit PR**: Create a pull request with a clear description

## 📋 Prerequisites

- **macOS**: Required for Metal framework development
- **Xcode**: Latest stable version
- **Swift**: Comes with Xcode
- **Git**: For version control
- **GitHub CLI** (optional): For enhanced GitHub integration

## 🔄 CI/CD Pipeline

Note: Visual tests are label-gated on pull requests. Add the label `visual-required` to run them on your PR. They always run on pushes to main.

Our GitHub Actions workflows automatically run on every push and pull request:

### 1. Swift/Metal Build (`swift-build.yml`)
- **Purpose**: Validates Swift compilation and Metal shader compilation
- **Runs on**: macOS runner
- **Key Steps**:
  - Sets up Xcode and Swift toolchain
  - Compiles `ShaderPlayground.swift` with Metal frameworks
  - Validates all `.metal` shader files
  - Creates build artifacts

### 2. Documentation Validation (`documentation.yml`)  
- **Purpose**: Ensures documentation quality and consistency
- **Runs on**: Ubuntu runner
- **Key Steps**:
  - Validates Markdown syntax using markdownlint
  - Checks for broken links
  - Verifies CHANGELOG.md format
  - Confirms WARP.md workflow compliance

### 3. Visual Testing (`visual-tests.yml`)
- **Purpose**: Captures visual evidence and runs visual regression tests
- **Runs on**: macOS runner
- **Key Steps**:
  - Compiles and runs Metal shader applications
  - Captures screenshots with proper naming conventions
  - Optimizes images for storage
  - Validates WARP.md visual evidence requirements

### 4. Tests and Quality Assurance (`test.yml`)
- **Purpose**: Runs tests and quality checks
- **Runs on**: macOS runner  
- **Key Steps**:
  - Creates test framework if needed
  - Runs Swift unit tests
  - Validates shader parameter combinations
  - Checks for memory leaks and performance issues
  - Generates test coverage reports

### 5. WARP Protocol Compliance (`warp-compliance.yml`)
- **Purpose**: Validates adherence to WARP workflow requirements
- **Runs on**: Ubuntu runner
- **Key Steps**:
  - Checks BUGS.md and CHANGELOG.md updates
  - Validates visual evidence for UI/shader changes
  - Verifies conventional commit format
  - Generates compliance reports

## 🏗️ Local Development

### Running Workflows Locally

#### Swift/Metal Build
```bash
# Compile the main application
swiftc -o MetalShaderStudio ShaderPlayground.swift \\
  -framework SwiftUI \\
  -framework MetalKit \\
  -framework AppKit \\
  -framework UniformTypeIdentifiers \\
  -parse-as-library

# Validate Metal shaders
for shader in shaders/*.metal; do
  xcrun -sdk macosx metal -c "$shader" -o /tmp/$(basename "$shader" .metal).air
done
```

#### Documentation Validation
```bash
# Install tools
npm install -g markdownlint-cli markdown-link-check

# Validate markdown
markdownlint *.md

# Check links  
find . -name "*.md" | xargs markdown-link-check
```

#### Visual Testing
```bash
# Compile and run for visual testing
./MetalShaderStudio &

# Capture screenshots (macOS)
screencapture -w Resources/screenshots/$(date +%Y-%m-%d_%H-%M-%S)_manual_test.png
```

#### Quality Tests
```bash
# Run Swift tests (if Package.swift exists)
swift test

# Check shader compilation
xcrun -sdk macosx metal -c shaders/*.metal
```

## 📝 WARP Workflow Requirements

Process policy: We operate with a single-flight PR policy for core work. Only one active (non-draft) PR should be open at a time; others remain draft and are rebased after the active PR merges.

Our project follows the WARP (Workflow Agent Review Protocol). **Every significant change must include**:

### 1. Documentation Updates
- **BUGS.md**: Document any issues discovered
- **CHANGELOG.md**: Record what was accomplished
- **Technical docs**: Update relevant documentation

### 2. Visual Evidence
- **Screenshots**: Capture visual changes in `Resources/screenshots/`
- **Naming convention**: `YYYY-MM-DD_HH-MM-SS_description.png`
- **Before/after**: For shader or UI modifications

### 3. Git Operations
- **Descriptive commits**: Clear, conventional format preferred
- **Logical grouping**: Group related changes together
- **No direct pushes to main**: Use pull requests

### 4. Testing Validation
- **No regressions**: Ensure existing functionality works
- **New tests**: Add tests for new functionality
- **Visual verification**: Confirm visual changes are correct

## 🎯 Pull Request Guidelines

### PR Title Format
Use conventional commit format:
- `feat: add new plasma shader variant`
- `fix: resolve Metal compilation error on older macOS`
- `docs: update shader documentation`
- `test: add visual regression tests`

### PR Description Template
```markdown
## Changes
Brief description of what this PR does.

## Visual Evidence
- [ ] Screenshots attached for UI/shader changes
- [ ] Before/after comparisons provided
- [ ] Visual evidence stored in Resources/screenshots/

## Documentation
- [ ] CHANGELOG.md updated
- [ ] BUGS.md updated if issues found
- [ ] Technical documentation updated

## Testing
- [ ] All workflows pass
- [ ] Local testing completed
- [ ] No regressions introduced

## WARP Compliance
- [ ] All after-action requirements completed
- [ ] Visual evidence provided for visual changes
- [ ] Documentation updated appropriately
```

## 🚨 Common Issues and Solutions

### Workflow Failures

**Swift Build Fails:**
- Check Xcode version compatibility
- Verify Metal framework availability
- Ensure all shader files have proper syntax

**Documentation Validation Fails:**
- Run markdownlint locally to fix syntax issues  
- Check for broken internal links
- Ensure CHANGELOG.md follows format

**Visual Tests Fail:**
- Verify screenshot naming convention
- Check Resources/screenshots/ directory exists
- Ensure visual evidence is provided for visual changes

**WARP Compliance Fails:**
- Update BUGS.md and CHANGELOG.md
- Add visual evidence for UI/shader changes
- Use conventional commit format

### Branch Protection

The `main` branch is protected and requires:
- ✅ All status checks must pass
- ✅ At least 1 approving review
- ✅ Branches must be up to date before merging
- ❌ No direct pushes allowed
- ❌ No force pushes allowed

## 🔧 Troubleshooting

### Metal Compilation Issues
```bash
# Check Metal compiler version
xcrun -sdk macosx metal --version

# Verify GPU support
system_profiler SPDisplaysDataType | grep "Metal"
```

### Swift Build Issues  
```bash
# Check Swift version
swift --version

# Clean build artifacts
rm -rf .build/ DerivedData/
```

### Missing Dependencies
```bash
# Install Xcode command line tools
xcode-select --install

# Install Homebrew packages
brew install imagemagick pngcrush
```

## 📞 Getting Help

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and general discussion  
- **Pull Request Comments**: For code-specific questions
- **WARP.md**: For workflow and process questions

## 🎨 Shader Development Guidelines

### Writing Metal Shaders
- Use descriptive parameter names
- Add comments explaining complex algorithms
- Test with various parameter ranges
- Follow consistent coding style

### Performance Considerations
- Minimize GPU memory usage
- Optimize for real-time rendering
- Test on different hardware configurations
- Profile shader performance

### Visual Quality
- Ensure shaders look good across resolutions
- Test parameter boundary conditions
- Provide good default parameter values
- Consider artistic intent and user experience

---

**Remember**: Quality over speed. Our CI/CD pipeline ensures every change maintains project standards and visual quality. When in doubt, ask for help! 🚀
