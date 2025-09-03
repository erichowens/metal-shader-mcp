# Metal Shader MCP

Live Metal shader development with real-time preview and hot reload via Model Context Protocol.

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

## Contributing

Contributions are welcome! Please submit pull requests or open issues for bugs and feature requests.

## License

MIT