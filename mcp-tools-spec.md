# Metal Shader MCP Tools Specification

## For Creative-Technical Directors

### Problem Statement
Creative directors working with Metal shaders need:
- Instant visual feedback when tweaking shaders
- No compile-run-wait cycles
- Easy parameter exploration
- Performance guarantees (60fps)
- Reusable shader components
- Cross-platform compatibility

### Core MCP Tools Required

## 1. Hot Reload Tool
```typescript
interface HotReloadTool {
  // Watch shader file, auto-recompile on save
  watch(path: string): void
  
  // Inject new shader without restarting
  inject(compiledShader: MTLLibrary): void
  
  // Preserve runtime state (time, params)
  preserveState(): ShaderState
  
  // Rollback on error
  fallback(): void
}
```

## 2. Parameter Discovery Tool
```typescript
interface ParameterExtractor {
  // Parse Metal shader for uniforms
  extract(source: string): Parameter[]
  
  // Auto-generate UI controls
  generateUI(params: Parameter[]): UIControls
  
  // Suggest ranges based on usage
  inferRanges(param: Parameter): Range
}
```

## 3. Shader Mixer Tool
```typescript
interface ShaderComposer {
  // Layer multiple shaders
  addLayer(shader: Shader, blend: BlendMode): Layer
  
  // Mix shader outputs
  blend(layers: Layer[]): MTLTexture
  
  // Transition between shaders
  crossfade(from: Shader, to: Shader, t: float): void
}
```

## 4. Performance Monitor Tool
```typescript
interface PerformanceProfiler {
  // Real-time GPU metrics
  measureGPU(): GPUMetrics
  
  // Frame timing analysis
  profileFrame(): FrameStats
  
  // Thermal monitoring
  thermalState(): ThermalStatus
  
  // Auto-optimize suggestions
  suggest(): Optimization[]
}
```

## 5. Shader Library Tool
```typescript
interface ShaderLibrary {
  // Common functions (noise, color, math)
  functions: Map<string, MetalFunction>
  
  // Search by tags/description
  search(query: string): MetalFunction[]
  
  // Inject into shader
  inject(func: MetalFunction, shader: string): string
  
  // Version control
  versions: Map<string, Version[]>
}
```

## 6. Visual Programming Tool
```typescript
interface NodeGraph {
  // Create shader nodes
  addNode(type: NodeType, props: NodeProps): Node
  
  // Connect nodes
  connect(from: Port, to: Port): Edge
  
  // Compile to Metal
  compile(): string
  
  // Import/export graphs
  serialize(): GraphJSON
}
```

## 7. Preset Manager Tool
```typescript
interface PresetManager {
  // Save current state
  save(name: string, params: UniformValues): Preset
  
  // Load preset
  load(preset: Preset): void
  
  // Animate between presets
  morph(from: Preset, to: Preset, curve: AnimationCurve): void
  
  // Export/share presets
  export(preset: Preset): string
}
```

## 8. Export Pipeline Tool
```typescript
interface ExportPipeline {
  // Cross-platform shader conversion
  toGLSL(shader: MetalShader): string
  toHLSL(shader: MetalShader): string
  toWGSL(shader: MetalShader): string
  
  // Platform-specific exports
  toShadertoy(shader: MetalShader): string
  toUnity(shader: MetalShader): UnityShader
  toUnreal(shader: MetalShader): UnrealMaterial
  
  // Media export
  toVideo(shader: MetalShader, settings: VideoSettings): MP4
  toGIF(shader: MetalShader, settings: GIFSettings): GIF
  toImageSequence(shader: MetalShader): PNG[]
}
```

## Implementation Priority

### Phase 1: Core Development Loop (Week 1)
- [x] Basic compilation
- [ ] Hot reload
- [ ] Parameter extraction
- [ ] Basic UI generation

### Phase 2: Creative Tools (Week 2)
- [ ] Shader mixing
- [ ] Preset system
- [ ] Library snippets
- [ ] Performance monitor

### Phase 3: Advanced Features (Week 3)
- [ ] Node editor backend
- [ ] Cross-platform export
- [ ] Video recording
- [ ] Shader marketplace

## Usage Example

```typescript
// Creative director's workflow
const mcp = new MetalShaderMCP()

// Start live session
mcp.hotReload.watch("./shaders/hero.metal")

// Extract and show parameters
const params = mcp.params.extract("hero.metal")
mcp.ui.show(params)

// Monitor performance
mcp.perf.start({ targetFPS: 60 })

// Mix two shaders
mcp.mixer.blend([
  { shader: "plasma.metal", opacity: 0.7 },
  { shader: "crystals.metal", opacity: 0.3 }
])

// Save a preset
mcp.presets.save("client_approved_v3")

// Export for production
mcp.export.toVideo("final.mp4", { 
  resolution: "4K", 
  fps: 60, 
  duration: 30 
})
```

## Benefits for Creative Directors

1. **Instant Feedback**: See changes as you type
2. **No Technical Barriers**: UI auto-generated from shader
3. **Performance Guaranteed**: Real-time monitoring
4. **Reusable Assets**: Library of effects
5. **Client-Ready Exports**: One-click video/GIF generation
6. **Version Control**: Save/load presets
7. **Cross-Platform**: Export to any target
8. **Visual Programming**: Node-based option for non-coders

## Technical Requirements

- Metal 3.0+ support
- Swift 5.9+ 
- TypeScript for MCP server
- Real-time compilation (<50ms)
- Memory-mapped shader updates
- GPU performance counters
- Automated testing suite

## Next Steps

1. Implement hot reload system
2. Build parameter extraction
3. Create preset manager
4. Add performance profiler
5. Develop export pipeline