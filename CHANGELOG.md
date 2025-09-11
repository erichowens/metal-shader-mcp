# Changelog

## [2025-09-11] - Comprehensive MCP server implementation

### Added
- Complete MCP tool suite implementation in src/index.ts:
  - `set_shader`: Set and compile shader with metadata extraction
  - `run_frame`: Render single frames to Resources/screenshots/
  - `export_sequence`: Export video/GIF/image sequences with ffmpeg
  - `save_session_snapshot`, `list_sessions`, `get_session`, `restore_session`: Session management
  - `set_baseline`, `compare_to_baseline`: Visual regression testing with pixelmatch
  - `extract_parameters`, `infer_parameter_ranges`, `generate_ui_controls`: Parameter extraction
  - `library_search`, `library_get`, `library_inject`, `library_list_categories`: Shader library
  - `get_example_shader`: Example shader retrieval
- Automatic parameter extraction from shader source with inline parsing
- Session persistence to Resources/sessions/ for shader development history
- PNG comparison with pixelmatch and pngjs for visual regression
- Inline shader function library with common utilities (noise, color conversions)
- Type declarations for pngjs and pixelmatch modules
- Server state management for current shader, sessions, and baselines

### Changed 
- Bumped MCP server version to 2.0.0 for MCP-first architecture
- Standardized all output paths to Resources/screenshots/
- Integrated parameter extraction and shader library directly into main server
- Added comprehensive error handling for all new tools

### CI
- Added GitHub Actions workflow `.github/workflows/node-tests.yml` to run Node/TypeScript Jest tests for the MCP server on Ubuntu runners
  - Uses Node 20 with npm cache
  - Runs `npm ci` and executes tests with `MCP_FAKE_RENDER=1` for deterministic, headless visual regression
  - Publishes a concise test summary to the job summary and uploads debug artifacts on failure
- Created a tracking issue to enable this workflow as a required status check in branch protection settings

### Infrastructure
- Jest policy test (Tests/policy.mcp-first.spec.ts) to block AppleScript and file-bridge patterns outside allowlist
- Core unit tests (Tests/mcp.core.spec.ts) for set_shader, run_frame, export_sequence
- Visual regression tests (tests/visual.regression.spec.ts) using set_baseline and compare_to_baseline
- Add Jest config for ESM TypeScript (jest.config.cjs)
- GitHub issues created to track MCP-first enforcement and migration
- Updated package.json with pixelmatch and pngjs dependencies

### Documentation
- WARP.md: Added "MCP-First Architecture & Enforcement" section
- CLAUDE.md: Added MCP-First Rules and updated tool priorities
- DESIGN.md: Removed communication/ bridge files from persistence paths
- README.md: Added status badge for MCP Node/TypeScript Tests workflow
- README.md: Added status badge for UI Smoke workflow

### Deprecated
- Resources/exports/ directory for new artifacts
- src/simple-mcp.ts remains as demo-only and will be removed after UI migration

## [2025-09-09] - CI EPIC Progress Sync

### Changed
- README.md: Added EPIC Progress Sync status badge.

### Added
- New GitHub Actions workflow `.github/workflows/epic-sync.yml` that runs `scripts/post_commit_sync.sh` in CI to post progress comments to EPIC issues.
  - Uses `GITHUB_TOKEN` with `issues: write` permission.
  - Triggers on push to any branch, and on PR opened/synchronize/reopened (non-fork) events.
  - Automatically includes commit URL, short SHA, PR link (when available), changed files, and any screenshot evidence in `Resources/screenshots/`.

### Documentation
- WARP.md updated with a "CI Automation: EPIC Progress Sync" section describing configuration, triggers, and secret handling.

All notable changes to the Metal Shader MCP project will be documented in this file.

## [2025-09-08] - CI stability, EPIC targeting, and branch protection policy updates

### Fixed
- GitHub Actions CI failing due to compiling only a subset of Swift sources. Updated build and visual-test workflows to compile all relevant Swift files (ShaderPlayground.swift, AppShellView.swift, HistoryTabView.swift, SessionRecorder.swift).
- UI Smoke job compile error addressed by adding `import SwiftUI` to `SessionRecorder.swift` to satisfy `@StateObject`’s `ObservableObject` constraint on macOS 15/Swift 6.1.2.
- SwiftUI macOS compatibility: Replaced `.onChange(of:) { _, new in ... }` with single-argument form to avoid requiring macOS 14+ (keeps macOS 12+ target).
- EPIC sync script robustness: Quoting and targeting fixes eliminate stray shell errors and prevent blanket comments.

### Changed
- Branch protection policy updated for solo maintenance:
  - Removed the “required PR review” gate.
  - Kept “require branches up-to-date” and “all required status checks must pass.”
  - Admin enforcement remains enabled.

### Notes
- Visual evidence and artifacts are captured in CI runs.
- Future work: migrate to Xcode project or Swift Package for automatic file discovery in CI.
- Added `docs/EPICS_MAP.json` to route EPIC updates by area (UI/UX, State & Workflow, CI/Regression, Library, Core MCP).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2025-09-07] - Complete CI/CD Pipeline and Branch Protection Setup

### Added
- **Comprehensive GitHub Actions CI/CD Pipeline**: 5 automated workflows for complete quality assurance
  - `swift-build.yml`: Swift/Metal compilation validation on macOS runners
  - `documentation.yml`: Markdown syntax, link validation, and documentation quality checks
  - `visual-tests.yml`: Visual evidence capture, screenshot optimization, and regression testing framework
  - `test.yml`: Swift unit tests, shader parameter validation, and quality assurance metrics
  - `warp-compliance.yml`: WARP protocol adherence validation with automated compliance reporting

- **Branch Protection Configuration**: Secure main branch with comprehensive protection rules
  - Require pull request reviews (minimum 1 approval)
  - Dismiss stale reviews on new commits
  - Require all status checks to pass before merging
  - Enforce for administrators
  - Block direct pushes and force pushes
  - Require branches to be up to date before merging

- **Workflow Configuration Files**:
  - `.github/markdownlint.json`: Markdown linting rules optimized for technical documentation
  - `.github/markdown-link-check.json`: Link validation configuration with proper timeout and retry settings
  - `.github/CONTRIBUTING.md`: Complete 270+ line development guide with workflow documentation

- **WARP Protocol Automation**:
  - Automatic BUGS.md and CHANGELOG.md validation for every commit
  - Visual evidence requirement enforcement for UI/shader changes
  - Conventional commit format checking and compliance reporting
  - After-action requirements verification with detailed reporting

- **Quality Assurance Features**:
  - Automated Metal shader compilation testing across all `.metal` files
  - Visual evidence capture with WARP-compliant naming conventions (`YYYY-MM-DD_HH-MM-SS_description.png`)
  - Documentation consistency validation and broken link detection
  - Test coverage reporting and quality metrics collection
  - Cross-platform workflow execution (macOS for Metal, Ubuntu for documentation)
  - Artifact storage with configurable retention periods (7-30 days)
  - Workflow status badges added to README.md for real-time CI/CD visibility

### Enhanced
- **Development Workflow**: All changes now require pull requests with automated quality gates
- **Documentation Quality**: Automated validation ensures all documentation meets standards
- **Visual Evidence**: Systematic capture and validation of visual changes per WARP protocol
- **Testing Framework**: Foundation for comprehensive Swift unit tests and visual regression testing
- **Compliance Monitoring**: Continuous validation of workflow protocol adherence

### Infrastructure
- **GitHub Actions Runners**: 
  - macOS-latest for Swift/Metal compilation and visual testing
  - Ubuntu-latest for documentation validation and compliance checking
- **Dependency Management**: Automated caching for Swift packages and Node.js dependencies
- **Artifact Management**: Structured storage for build artifacts, test reports, and visual evidence
- **Notification System**: Workflow failure notifications and status reporting

### Security
- **Branch Protection**: Prevents unauthorized direct changes to main branch
- **Review Requirements**: Ensures all changes undergo code review process
- **Status Check Enforcement**: Blocks merges that fail quality gates
- **Administrator Enforcement**: No exceptions for administrative users

### Visual Evidence
- GitHub Actions workflows successfully configured and operational
- Branch protection rules active and preventing direct pushes
- Workflow status badges displaying real-time CI/CD status
- Complete development workflow documentation in CONTRIBUTING.md
- All workflows follow WARP protocol for visual evidence and documentation requirements

### Notes
- Initial workflow setup required temporary branch protection removal for bootstrap push
- All subsequent changes must go through pull request process
- Workflows will establish baseline visual evidence on first successful runs
- CI/CD pipeline ready for immediate use in development workflow

## [2025-09-07] - GitHub Setup and Repo Hygiene

### Changed
- Verified Git remote: origin -> https://github.com/erichowens/metal-shader-mcp.git
- Pushed pending local commits on main to origin (was ahead by +3)
- Updated .gitignore to exclude local app binary (MetalShaderStudio), macOS app bundles (*.app), and secret-laden config (warp_drive_mcp_import.json)

### Security
- Ensured secrets are not tracked in Git. Store keys in .env or your shell env. See .env.example for sources and variable names.
- warp_drive_mcp_import.json kept untracked; contains local paths and env placeholders.

### Visual Evidence
- N/A (no UI/shader changes).

## [2025-09-07] - REPL Plan, UI Design, Pragmatic Docs, and Sync Hooks

### Added
- **REPL-focused MCP tool roadmap** prioritized for Claude’s visual learning
- **EPIC: SwiftUI App UI/UX + Educational Library** with persistence plan
- **DESIGN.md**: Wireframes, user stories, view hierarchy, persistence model
- **CLAUDE.md** rewritten as pragmatic REPL guide aligned with WARP.md
- Updated internal todos to reflect new EPICs and priorities

### Notes
- Added post-commit sync hook (local) that posts progress comments to EPIC issues via gh CLI
- Provide scripts/install_hooks.sh to install hooks locally (git does not version-control hooks)
- Nightly smoke test planned to render a canonical shader and catch breakage

### Changed
- **WARP.md Workflow Protocol**: Consolidated multi-agent workflow into single-agent responsibilities
- Updated compilation commands to reflect ShaderPlayground.swift as main application file
- Revised workflow timing expectations to be realistic for single-agent execution (5-10 minutes for complex changes)
- Reorganized agent responsibilities into cohesive categories: Code Review & Quality, Documentation, Task Management, Metal Shader Specific

### Removed
- Deleted agent-orchestrator.ts - unnecessary complexity, Warp already provides orchestration
- Removed fake "agent" abstractions that provided no real value
- Eliminated references to multiple agents in WARP.md workflow documentation

## [Unreleased]

### Fixed
- **Critical UI Synchronization**: Fixed shader library loading appearing empty
- **Text Editor Empty Content**: Fixed code editor showing blank when switching tabs
- **Tab Selection Sync**: Fixed selectedTab state not synchronized between components
- **Compilation Target**: Fixed compileCurrentShader() always targeting first tab instead of selected tab
- **Auto-compilation**: Fixed missing auto-compilation on text changes and library loading
- **Library Loading**: Fixed shader library items not appearing to load due to UI sync issues

### Added
- **Advanced Error Detection System**: Comprehensive real-time error detection with syntax validation
- **Enhanced Code Editor**: Professional code editor with syntax highlighting, error overlays, and tooltips
- **Intelligent Error Panel**: Dedicated error panel with filtering, search, and detailed error information
- **Visual Testing Framework**: Automated screenshot capture and visual regression testing system
- **Error Recovery Engine**: Intelligent suggestions and automated fixes for common shader errors
- **Real-time Validation**: Live syntax checking as user types with immediate feedback
- Comprehensive workflow documentation in WARP.md
- Creative workflow integration in CLAUDE.md  
- Visual testing framework requirements in VISUAL_TESTING.md
- Agent-based development process
- Automated screenshot capture and visual diff scripts
- Directory structure for visual evidence collection
- Integration of artistic workflow with technical validation
- Multi-agent coordination protocols

### Enhanced
- **Error Detection Engine**: Advanced Metal shader syntax analysis with detailed error categorization
- **Code Highlighting**: Sophisticated syntax highlighting with Metal-specific keywords and functions
- **Error Recovery**: Automated fix suggestions with intelligent error pattern recognition
- **User Experience**: Hover tooltips, error navigation, and contextual help for shader development
- **Visual Validation**: Screenshot-based testing for UI consistency and regression prevention
- README.md updated with workflow requirements
- BUGS.md expanded with resolution tracking
- Documentation consistency across all .md files
- Git workflow optimized for creative development
- Cleaned up redundant/broken scripts - only working ones remain

### Infrastructure
- **New Core Components**:
  - `ErrorDetectionEngine.swift` - Advanced error detection and analysis system
  - `CodeEditor.swift` - Professional code editor with syntax highlighting and error overlays
  - `ErrorPanel.swift` - Comprehensive error management UI component
  - `VisualTestingFramework.swift` - Automated visual testing and regression detection
- **Enhanced Models**: Extended `CompilationError` with detailed error context, severity levels, and suggestions
- **Real-time Processing**: Debounced syntax validation with intelligent error categorization
- `scripts/screenshot_app.sh` - Bulletproof window capture using CGWindowID
- `scripts/find_window_id.py` - Swift-powered visible window detection
- `scripts/debug_window.py` - Window debugging utility (optional)
- `Resources/screenshots/` directory structure established

### Visual Evidence
- **Error Detection System**: Visual evidence captured showing enhanced error highlighting and tooltips
- **Code Editor**: Screenshots demonstrating syntax highlighting, error overlays, and real-time validation
- **Error Panel**: Visual documentation of comprehensive error management interface
- **Testing Framework**: Automated screenshot capture system for regression testing
- **User Experience**: Before/after comparisons showing improved developer workflow
- Workflow documentation system fully operational
- Agent coordination protocols defined and documented
- Visual testing framework ready for implementation
- All documentation files consistent and cross-referenced

## [0.1.0] - 2024-09-06

### Added
- Initial Metal Shader Studio application with SwiftUI interface
- Basic shader compilation and rendering system
- Parameter extraction and manipulation capabilities
- Shader library with basic plasma and kaleidoscope effects
- MCP server integration for AI-assisted shader development
- Real-time shader editing with syntax highlighting
- Export functionality framework (PNG, video)

### Core Components
- `MetalStudioMCPEnhanced.swift`: Main application interface
- `MetalStudioMCPCore.swift`: Core rendering and Metal integration  
- `MetalStudioMCPModels.swift`: Data models and shader management
- `MetalStudioMCPComponents.swift`: UI components and parameter controls
- Shader library: plasma, kaleidoscope, fractals, and procedural patterns

### Infrastructure  
- Xcode project configuration for macOS development
- Git repository with proper .gitignore for Xcode/Swift projects
- Build scripts and compilation toolchain setup
- Node.js MCP server implementation
- TypeScript integration for extended functionality

### Documentation
- README.md with project overview and setup instructions
- CLAUDE.md with creative vision and AI interaction patterns
- BUGS.md for tracking technical issues and solutions
- Setup and implementation guides

### Known Issues
- Text editor keyboard input intermittent
- MCP server connection stability needs improvement
- Export functionality requires full implementation
- Visual testing framework not yet implemented

### Visual Evidence
- Project structure and basic UI established
- Shader compilation and rendering pipeline functional
- Parameter manipulation system operational
- Library loading and shader switching working

---

## Change Categories

### Added
- New features, functionality, or components

### Changed  
- Changes in existing functionality or behavior

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features or components

### Fixed
- Bug fixes and issue resolutions

### Security
- Vulnerability fixes and security improvements

### Visual
- UI changes, shader modifications, visual improvements

### Performance
- Performance improvements and optimizations

---

*This changelog documents the evolution of the Metal Shader MCP from concept to functional creative tool, tracking both technical progress and artistic development.*
