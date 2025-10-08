# Bug Log & Technical Issues

## Project Status: Fresh Start (2025-09-07)
Starting clean implementation of Metal Shader MCP with three-phase approach.

## Current Issues

### 2025-10-01 — CoreML Model Loading Error (RESOLVED)
- **Problem**: App showed error `[CoreML] Failed to load config/model: Error Domain=com.apple.CoreML...` on startup because the StyleTransfer.mlmodelc model file referenced in coreml_config.json didn't exist.
- **Fix**: Modified CoreMLPostProcessor to check if model file exists before attempting to load. If file doesn't exist, the feature fails silently as it's optional functionality.
- **Changes**: 
  - Added file existence check in `Sources/MetalShaderCore/CoreMLPostProcessor.swift`
  - Added comment to `Resources/communication/coreml_config.json` noting feature is disabled
- **Status**: Resolved - app now starts cleanly without error messages
- **Follow-up**: Create task to implement actual StyleTransfer CoreML model if/when this feature is needed

### 2025-09-11 — PR test check blocked (missing SPM)
- Problem: Required check "Swift Tests and Quality Checks" on PRs never reached green because the repository lacked a Swift Package, causing `swift test` to fail or not report properly.
- Fix: Added `Package.swift` and a minimal library + test target. Tests now run and skip gracefully if Metal is unavailable on the runner.
- Validation: CI jobs complete with a definitive status; auto-merge is unblocked when other required checks pass.
*No issues yet - project freshly started*

### 2025-09-08 — EPIC auto-comment robustness
- Problem: Post-commit EPIC sync printed `command not found` lines like `build(ci)::` when commits included conventional scopes. The heredoc in the sync script wasn’t fully protected and quoting was fragile; script also posted to all EPICs indiscriminately.
- Fix:
  - Hardened `scripts/post_commit_sync.sh` with strict tool checks and safe quoting (literal heredoc) to avoid any accidental evaluation of commit text.
  - Added targeted routing via `docs/EPICS_MAP.json` so only relevant EPICs are updated.
- Validation: No more stray shell errors on commit; comments go only to the mapped EPICs.
- Follow-up: Add small mapping tests (see scripts/tests) and consider expanding mappings as codebase grows.

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
## [RESOLVED] ShaderRenderCLI Compilation Errors

**Status:** ✅ RESOLVED (2025-10-08)

**Issues Fixed:**
1. Invalid `.blit` usage in MTLTextureUsage (line 62)
   - **Fix:** Removed `.blit` from texture descriptor
   - **Correct usage:** `.usage = [.renderTarget, .shaderRead]`

2. Invalid string interpolation syntax (line 89)
   - **Fix:** Changed from `\(outPath) (\(width)x\(height))` to proper interpolation
   - **Correct syntax:** Properly escaped string interpolation

**Resolution:**
- Committed fix in commit 125ca71
- All CI checks now passing
- PR #51 successfully merged to main

**Prevention:**
- Visual regression tests in place
- Compilation checks in CI
- Swift tests validate shader rendering
