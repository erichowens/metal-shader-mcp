# WARP Agent Workflow Protocol

## 🔄 After-Action Requirements
**CRITICAL**: After every significant agent action, these steps MUST be completed:

### 1. **BUGS.md Update** 
- Document any issues discovered during the action
- Update status of existing bugs (resolved, persisting, or changed)
- Add new bugs with reproduction steps and context
- Include workarounds or partial solutions discovered

### 2. **CHANGELOG.md Entry**
- Record what was accomplished in this action
- Note any breaking changes or new features
- Document parameter changes, new shaders, or workflow improvements
- Include version info if applicable

### 3. **Visual Evidence Collection**
- Take screenshots of visual changes (REQUIRED for UI/shader work)
- Save visual artifacts to `Resources/screenshots/` with timestamps
- For shader work: capture before/after comparisons
- Document visual evidence in the changelog entry

### 4. **Git Operations**
- Stage and commit changes with descriptive commit messages
- Push to GitHub if working on shared features
- Create feature branches for experimental work
- Tag significant milestones

### 5. **Testing Validation**
- Run existing tests to ensure no regressions
- Create new tests for new functionality
- For visual work: implement or update visual regression tests
- Document test coverage changes

## 🤖 Main Agent Responsibilities

As the primary development agent, you are responsible for all aspects of the project workflow. These responsibilities are organized by category but should be executed as a cohesive development process:

### Code Review & Quality
- Review all code changes before commit
- Ensure adherence to Metal and Swift best practices
- Verify shader optimization and performance
- Check parameter boundary conditions
- Provide honest assessment of changes
- Identify potential issues before they become bugs
- Validate visual output quality
- Ensure user experience improvements

### Documentation Management
- Maintain consistency across all .md files
- Update technical documentation as code evolves
- Keep API documentation current
- Ensure examples remain functional
- Document creative decisions and their rationale

### Task & Workflow Management
- Track completion of after-action requirements
- Ensure no steps are skipped in the workflow
- Maintain project momentum and focus
- Prioritize tasks based on dependencies and importance
- Create and manage todo lists when tasks require 3+ steps

### Metal Shader Specific
- Evaluate aesthetic quality of shader output
- Suggest artistic improvements
- Maintain visual consistency across shaders
- Monitor shader compilation times
- Profile GPU usage and memory consumption
- Identify optimization opportunities
- Ensure cross-device compatibility

## 📸 Visual Testing Framework

### Required Visual Tests
1. **Shader Render Tests**: Capture output of each shader with standard parameters
2. **UI Component Tests**: Screenshot key UI states
3. **Parameter Change Tests**: Visual diff when parameters are adjusted
4. **Cross-Resolution Tests**: Ensure shaders work across display sizes

### Screenshot Naming Convention
```
Resources/screenshots/YYYY-MM-DD_HH-MM-SS_<feature>_<action>.png
Resources/screenshots/2024-09-06_09-15-30_plasma_shader_initial_render.png
Resources/screenshots/2024-09-06_09-16-45_ui_parameter_panel_expanded.png
```

### Visual Regression Testing
- Compare screenshots against baseline images
- Flag significant visual changes for manual review
- Maintain baseline image library
- Automate visual diff generation

## 🔗 Integration with Creative Process

### During Shader Development
1. **Baseline Capture**: Screenshot initial shader state
2. **Iterative Documentation**: Record each significant visual change
3. **Parameter Mapping**: Document visual effects of parameter changes
4. **Artistic Intent Recording**: Note creative goals and how they're achieved

### During Bug Fixes
1. **Problem Documentation**: Visual evidence of the issue
2. **Solution Verification**: Before/after screenshots
3. **Regression Prevention**: Add visual tests to prevent reoccurrence
4. **User Impact Assessment**: How fix improves user experience

## 🎯 Success Metrics

### Documentation Quality
- All changes documented within 5 minutes of implementation
- Visual evidence provided for 100% of UI/shader changes  
- Git history provides clear narrative of project evolution
- No undocumented breaking changes

### Testing Coverage
- Every shader has visual regression tests
- UI components have screenshot-based tests
- Parameter changes are visually validated
- Cross-platform rendering verified

### Workflow Efficiency  
- After-action workflow completed in reasonable time (5-10 minutes for complex changes)
- No workflow steps skipped or forgotten
- Tasks prioritized and executed systematically
- Continuous improvement in process efficiency

## 🛠 Tools and Commands

### Screenshot Capture (macOS)
```bash
# Capture Metal Shader app window
./scripts/screenshot_app.sh "description"

# Manual capture selection
screencapture -s ~/path/to/screenshot.png

# Debug window issues
python3 scripts/debug_window.py

# Find window ID for debugging
python3 scripts/find_window_id.py
```

### Git Workflow
```bash
# Standard commit with visual evidence
git add .
git commit -m "feat: implement plasma shader variations

- Added 3 new plasma shader variants
- Enhanced parameter responsiveness  
- Visual evidence: Resources/screenshots/2024-09-06_plasma_variants.png
- Closes #issue-number"

git push origin feature/plasma-enhancements
```

### Test Execution
```bash
# Compile and run the Metal Shader app
swiftc -o MetalShaderStudio ShaderPlayground.swift \
  -framework SwiftUI \
  -framework MetalKit \
  -framework AppKit \
  -framework UniformTypeIdentifiers \
  -parse-as-library

./MetalShaderStudio &

# Capture screenshots for visual testing
./scripts/screenshot_app.sh "test_description"

# Run Swift tests (when implemented)
swift test --filter VisualRegressionTests

# Verify screenshot capture works
python3 scripts/find_window_id.py
```

## 🚨 Critical Failure Points

### Never Skip These Steps
1. **Visual evidence for visual changes** - Non-negotiable
2. **BUGS.md updates when issues found** - Must be immediate  
3. **CHANGELOG.md entries** - Required for all changes
4. **Git commits with descriptive messages** - Essential for history

### Red Flags
- Changes pushed without visual evidence
- Bugs discovered but not documented
- Code committed without testing
- Documentation left inconsistent
- Workflow steps completed out of order

---

*This workflow ensures that every action builds toward a more robust, well-documented, and visually stunning shader development environment. The discipline of visual evidence and systematic documentation transforms development from ad-hoc exploration into purposeful artistic and technical progress. While originally designed for multiple agents, this workflow has been adapted for efficient execution by a single primary agent handling all responsibilities.*

---

**Last Updated**: 2025-09-07  
**Project Structure**: ShaderPlayground.swift as main application file  
**Key Changes**: Consolidated multi-agent workflow into single agent responsibilities
