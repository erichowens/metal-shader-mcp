# Bug Log & Technical Issues

## Project Status: Fresh Start (2025-09-07)
Starting clean implementation of Metal Shader MCP with three-phase approach.

## Current Issues
*No issues yet - project freshly started*

### 2025-09-08 — CI and Branch Protection
- Issue: GitHub Actions CI for PRs compiled only ShaderPlayground.swift which referenced types declared in other Swift files (AppShellView, HistoryTabView, SessionRecorder), causing missing-type build failures.
- Also: UI Smoke job errored that `@StateObject` requires `SessionRecorder` to conform to `ObservableObject` due to missing `import SwiftUI` on CI’s toolchain.
- Fix:
  - Updated workflows to compile all Swift sources: ShaderPlayground.swift AppShellView.swift HistoryTabView.swift SessionRecorder.swift.
  - Added `import SwiftUI` to SessionRecorder.swift so the `StateObject` constraint is satisfied consistently on macOS 15/Swift 6.1.2.
- Validation: All required checks now pass (Build, Tests, Visual Testing, UI Smoke, Docs, WARP).
- Branch Protection: Required review removed (solo maintainer), but all status checks remain required and branches must be up-to-date before merge.
- Workaround/Notes: When adding new Swift files that are part of the app shell, ensure the CI compile step includes them until an Xcode project or SwiftPM target is introduced for automatic file discovery.

### 2025-09-07 — GitHub Setup Notes
- No blocking issues encountered while verifying/pushing to GitHub.
- Preventative: Added ignore rules for `MetalShaderStudio`, `*.app`, and `warp_drive_mcp_import.json` to avoid committing binaries and secrets.
- Secrets: Use .env (see .env.example) or shell environment for keys (Brave, HF, Notion, Stability, GitHub). Do not store tokens in repo files.

## Compilation Command
```bash
swiftc -o MetalShaderStudio ShaderPlayground.swift \
  -framework SwiftUI \
  -framework MetalKit \
  -framework AppKit \
  -framework UniformTypeIdentifiers \
  -parse-as-library

./MetalShaderStudio
```

## Debug Strategy
When debugging issues, ALWAYS do a web search first:
- NSTextView editing issues → Search StackOverflow
- Process/NSTask issues → Search Apple Developer Forums
- Metal compilation → Search Metal by Example
- SwiftUI bindings → Search SwiftUI labs

## Workflow Integration
- Visual evidence collection system ready
- Screenshot scripts available in scripts/
- Documentation workflow per WARP.md
- Git workflow optimized for iterative development
