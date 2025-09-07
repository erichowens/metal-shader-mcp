# Metal Shader MCP - Claude's Shader Development Playground

[![Swift/Metal Build](https://github.com/erichowens/metal-shader-mcp/actions/workflows/swift-build.yml/badge.svg)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/swift-build.yml)
[![Tests](https://github.com/erichowens/metal-shader-mcp/actions/workflows/test.yml/badge.svg)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/test.yml)
[![Documentation](https://github.com/erichowens/metal-shader-mcp/actions/workflows/documentation.yml/badge.svg)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/documentation.yml)
[![Visual Tests](https://github.com/erichowens/metal-shader-mcp/actions/workflows/visual-tests.yml/badge.svg)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/visual-tests.yml)
[![WARP Compliance](https://github.com/erichowens/metal-shader-mcp/actions/workflows/warp-compliance.yml/badge.svg)](https://github.com/erichowens/metal-shader-mcp/actions/workflows/warp-compliance.yml)

A complete system for AI-assisted Metal shader development where Claude can write, modify, and visually iterate on shaders in real-time.

## Features

- **Live Compilation**: Compile Metal shaders in real-time with error reporting
- **Hot Reload**: Automatic recompilation on file changes
- **Performance Profiling**: Measure FPS, GPU/CPU time, and memory usage
- **Preview Engine**: Real-time shader preview with WebSocket updates
- **Shader Templates**: Built-in shader examples and effects
- **MCP Integration**: Seamless integration with AI assistants

## Installation

```bash
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

## Contributing

Contributions are welcome! Please follow the workflow requirements in `WARP.md`:

1. Create feature branch from main
2. Implement changes with visual evidence
3. Update relevant documentation
4. Run visual regression tests
5. Submit pull request with screenshots

## License

MIT
