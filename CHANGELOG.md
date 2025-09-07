# Changelog

All notable changes to the Metal Shader MCP project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

## [2025-09-07] - REPL Plan, UI Design, and Pragmatic Docs

### Added
- **REPL-focused MCP tool roadmap** prioritized for Claude’s visual learning
- **EPIC: SwiftUI App UI/UX + Educational Library** with persistence plan
- **DESIGN.md**: Wireframes, user stories, view hierarchy, persistence model
- **CLAUDE.md** rewritten as pragmatic REPL guide aligned with WARP.md
- Updated internal todos to reflect new EPICs and priorities

### Notes
- GitHub issue creation via MCP blocked (401). Added task to configure credentials and re-run issue creation.
- We will create GitHub epics once auth is configured (or use gh CLI).

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
