# Metal Shader MCP - Claude's Shader Development Playground

[![Swift/Metal Build](https://github.com/erichowens/metal-shader-mcp/actions/workflows/swift-build.yml/badge.svg)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/swift-build.yml)
[![Tests](https://github.com/erichowens/metal-shader-mcp/actions/workflows/test.yml/badge.svg)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/test.yml)
[![MCP Node/TypeScript Tests](https://github.com/erichowens/metal-shader-mcp/actions/workflows/node-tests.yml/badge.svg)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/node-tests.yml)
[![Documentation](https://github.com/erichowens/metal-shader-mcp/actions/workflows/documentation.yml/badge.svg)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/documentation.yml)
[![Visual Tests](https://github.com/erichowens/metal-shader-mcp/actions/workflows/visual-tests.yml/badge.svg)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/visual-tests.yml)
[![WARP Compliance](https://github.com/erichowens/metal-shader-mcp/actions/workflows/warp-compliance.yml/badge.svg)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/warp-compliance.yml)
[![EPIC Progress Sync](https://github.com/erichowens/metal-shader-mcp/actions/workflows/epic-sync.yml/badge.svg?branch=main)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/epic-sync.yml)

A complete system for AI-assisted Metal shader development where Claude can write, modify, and visually iterate on shaders in real-time.

## Project overview

Note: The legacy file-bridge (writing commands to Resources/communication) is being deprecated in favor of a strict MCP client. See Deprecation notice below.
Metal Shader MCP is a macOS SwiftUI + Metal playground with a disciplined workflow for shader iteration, visual evidence, and CI. An MCP layer is planned to let AI assistants interact with the app (compile, preview, snapshot), but today the primary entry point is the macOS app you can compile and run locally.

## Current state (as of 2025-09-08)
- macOS app (SwiftUI + Metal) builds and runs locally and in CI.
- Live shader editing with a simple renderer and screenshot/export helpers.
- Session Browser (History tab) captures per-session snapshots (code + image + meta).
- CI enforces: build, tests, visual-evidence capture, WARP workflow compliance, UI smoke (tab selection/status), docs checks.
- Branch protection requires all status checks to pass and branches to be up-to-date (no required external review since this is solo-maintained).

## Roadmap
- MCP server integration to drive the macOS app (compile/preview/snapshot) from tools.
- Visual regression tests with baselines across multiple resolutions.
- Shader library with names, descriptions, and persistent metadata (see WARP/metadata rules).
- Export pipelines (PNG/video) with parameter sweeps and performance profiling.
- Xcode project or Swift Package targets for automatic file discovery in CI.

## Quick start (macOS app)
- Prereqs: macOS with Xcode (latest stable), Metal-capable device.
- Build and run locally:

```bash
swiftc -o MetalShaderStudio \
  ShaderPlayground.swift AppShellView.swift HistoryTabView.swift SessionRecorder.swift \
  Sources/MetalShaderCore/MCPClient.swift \
  -framework SwiftUI -framework MetalKit -framework AppKit -framework UniformTypeIdentifiers \
  -parse-as-library

./MetalShaderStudio --tab history
```

## Features

- **Live Compilation**: Compile Metal shaders in real-time with error reporting
- **Hot Reload**: Automatic recompilation on file changes
- **Performance Profiling**: Measure FPS, GPU/CPU time, and memory usage
- **Preview Engine**: Real-time shader preview with WebSocket updates
- **Shader Templates**: Built-in shader examples and effects
- **MCP Integration**: Seamless integration with AI assistants

## Installation

- macOS app (current): see Quick start above.
- MCP server (planned): the existing npm scripts are placeholders for the future MCP server. They are not required to run the macOS app today.

```bash
# Planned (MCP server), not required for the macOS app today
npm install
npm run build
```

## Usage

### Start MCP Server

```bash
npm start
```

### Development Mode

```bash
npm run dev
```

### Available MCP Tools

1. **compile_shader**: Compile Metal shader code
   - Supports AIR, metallib, and SPIRV targets
   - Optimization options
   - Error and warning reporting

2. **preview_shader**: Generate preview images
   - Real-time rendering
   - Customizable resolution
   - Touch interaction support

3. **update_uniforms**: Update shader parameters
   - Time, touch position, resolution
   - Custom uniform values

4. **profile_performance**: Performance metrics
   - FPS measurement
   - GPU/CPU time tracking
   - Memory usage monitoring

5. **hot_reload**: File watching
   - Automatic recompilation
   - WebSocket notifications
   - Development dashboard

6. **validate_shader**: Syntax validation
   - Error detection
   - Performance suggestions
   - Code analysis

## Shader Development

### Example: Kaleidoscope Effect

```metal
#include <metal_stdlib>
using namespace metal;

fragment float4 kaleidoscopeFragment(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    // Kaleidoscope transformation
    float2 uv = kaleidoscope(in.texCoord, 6, uniforms.time);
    
    // Generate RGBY color blocks
    float4 color = generateColorBlock(uv, uniforms.blockSize);
    
    return color;
}
```

### Performance Requirements

- **Target**: 60fps on modern devices
- **Memory**: Efficient memory usage
- **Compilation**: <500ms

## Architecture

```
metal-shader-mcp/
├── src/
│   ├── index.ts         # MCP server
│   ├── compiler.ts      # Metal compilation
│   ├── preview.ts       # Preview engine
│   ├── hotReload.ts     # File watching
│   ├── profiler.ts      # Performance profiling
│   └── parameters.ts    # Uniform management
├── shaders/
│   └── kaleidoscope.metal  # Example shader
└── dist/                # Compiled output
```

## Hot Reload Dashboard

Access the development dashboard at:
```
http://localhost:3000/dashboard
```

Features:
- Real-time compilation status
- Error and warning display
- Performance metrics
- File watching status

## Shader Examples

The included kaleidoscope shader demonstrates:
- Real-time geometric transformations
- Perlin noise generation
- Color block effects
- Interactive animations
- Performance optimization techniques

## Performance Optimization

The profiler measures:
- Average frame time
- Frames per second
- GPU processing time
- CPU overhead
- Memory usage
- Power consumption estimate

## Development Workflow

### After-Action Requirements
Every significant development action must complete these steps:

1. **Update BUGS.md** - Document any issues discovered
2. **Update CHANGELOG.md** - Record what was accomplished  
3. **Capture Visual Evidence** - Screenshots for UI/shader changes
4. **Run Tests** - Ensure no regressions introduced
5. **Git Operations** - Commit with descriptive messages

See `WARP.md` for detailed workflow documentation.

### Visual Testing
This project uses visual evidence collection for shader development:

```bash
# Capture screenshots of current state
./scripts/screenshot_app.sh "feature_description"

# Debug window capture issues
python3 scripts/debug_window.py

# Run visual tests (when implemented)
swift test --filter VisualRegressionTests
```

### Documentation Files
- **WARP.md** - Agent workflow requirements
- **CLAUDE.md** - Creative vision and AI interaction patterns
- **VISUAL_TESTING.md** - Visual testing framework
- **BUGS.md** - Current issues and solutions
- **CHANGELOG.md** - Project evolution history

## Deprecation notice (file-bridge)

- The file-bridge (commands.json polling) is transitional and will be removed once the strict MCP client (MCPLiveClient) is integrated into the Swift app via MCPBridge.
- Target: replace bridge with proper MCP transport (stdio/websocket), remove polling, add robust error handling.
- Timeline: as soon as PR #29 merges, we’ll proceed with PR #32 to complete this migration.

## Contributing

Contributions are welcome! Please follow the workflow requirements in `WARP.md`:

1. Create feature branch from main
2. Implement changes with visual evidence
3. Update relevant documentation
4. Run visual regression tests
5. Submit pull request with screenshots

## License

MIT
