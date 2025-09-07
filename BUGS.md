# Bug Log & Technical Issues

## Project Status: Fresh Start (2025-09-07)
Starting clean implementation of Metal Shader MCP with three-phase approach.

## Current Issues
*No issues yet - project freshly started*

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
