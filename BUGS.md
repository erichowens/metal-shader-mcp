# Bug Log & Technical Issues

## Project Status: Fresh Start (2025-09-07)
Starting clean implementation of Metal Shader MCP with three-phase approach.

## Current Issues
*No issues yet - project freshly started*

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
