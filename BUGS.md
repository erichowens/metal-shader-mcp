# Bug Log & Technical Issues

## Current Issues
❌ Text editor sometimes not editable (keyboard input issues) - NEEDS FOCUS FIX
❌ MCP server stops immediately after starting  
❌ Export buttons (PNG, Video) need full implementation
❌ Gray rendering when shaders compile but don't render

## Critical Issues FIXED (2025-09-07)
✅ **Shader library loading invisible** - Tab selection not synchronized
✅ **Text editor shows no content** - Binding used local selectedTab instead of workspace.selectedTabIndex  
✅ **Library selection doesn't compile** - Added auto-compilation on library load
✅ **Compilation targets wrong shader** - compileCurrentShader() was always using first tab, now uses selectedTabIndex
✅ **Auto-compile on typing not working** - Added scheduleCompilation() to text change handlers

## Known Working Solutions
1. **Text Editor**: Uses CustomTextView class with proper NSViewRepresentable pattern
2. **Syntax Highlighting**: isRichText=false, manage attributes with beginEditing/endEditing
3. **Window Size**: 900x600 minimum (was 1400x800, too large)

## Compilation Command
```bash
swiftc -o MetalStudioMCPFinal \
  MetalStudioMCPEnhanced.swift \
  MetalStudioMCPCore.swift \
  MetalStudioMCPModels.swift \
  MetalStudioMCPComponents.swift \
  -framework SwiftUI \
  -framework MetalKit \
  -framework AppKit \
  -framework UniformTypeIdentifiers

./MetalStudioMCPFinal
```

## Recently Resolved
✅ Documentation workflow established (2024-09-06)
✅ Visual testing framework designed (2024-09-06)
✅ Agent workflow protocols defined (2024-09-06)
✅ **Screenshot capture failure FIXED** (2024-09-06) - Using CGWindowID via Swift
✅ Window detection prioritizes visible windows over hidden ones
✅ Cleaned up redundant/broken screenshot scripts

## Debug Strategy
When debugging issues, ALWAYS do a web search first:
- NSTextView editing issues → Search StackOverflow
- Process/NSTask issues → Search Apple Developer Forums
- Metal compilation → Search Metal by Example
- SwiftUI bindings → Search SwiftUI labs

## Workflow Integration
- Visual evidence collection system implemented
- Automated testing scripts created
- Documentation consistency maintained
- Git workflow optimized for creative development
