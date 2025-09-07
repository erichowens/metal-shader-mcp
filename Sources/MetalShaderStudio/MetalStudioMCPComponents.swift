import SwiftUI
import MetalKit
import AppKit
import Metal

// MARK: - Metal Rendering View
struct MetalRenderingView: NSViewRepresentable {
    @EnvironmentObject var workspace: WorkspaceManager
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = workspace.renderer.device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = false  // Use timer-based updates
        mtkView.isPaused = !workspace.isPlaying
        mtkView.preferredFramesPerSecond = 60
        
        // Enable mouse tracking - will be set up later when view is ready
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.isPaused = !workspace.isPlaying
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        let parent: MetalRenderingView
        private var startTime: Double = CACurrentMediaTime()
        private var mousePosition: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
        
        init(_ parent: MetalRenderingView) {
            self.parent = parent
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Update resolution parameter
            parent.workspace.resolutionParameter.value = .vector2(Float(size.width), Float(size.height))
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let commandBuffer = parent.workspace.renderer.commandQueue.makeCommandBuffer(),
                  let pipelineState = parent.workspace.renderer.pipelineState else { 
                // If no pipeline state, clear to gray to show something is wrong
                guard let commandBuffer = parent.workspace.renderer.commandQueue.makeCommandBuffer(),
                      let descriptor = view.currentRenderPassDescriptor,
                      let drawable = view.currentDrawable else { return }
                      
                descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1)
                let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
                encoder.endEncoding()
                commandBuffer.present(drawable)
                commandBuffer.commit()
                return
            }
            
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
            
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
            encoder.setRenderPipelineState(pipelineState)
            
            // No vertex buffer needed - vertex shader uses [[vertex_id]]
            
            // Calculate animated time
            let currentTime = CACurrentMediaTime()
            var time: Float = 0.0
            
            if parent.workspace.isPlaying {
                time = Float(currentTime - startTime)
                // Update time parameter for UI
                DispatchQueue.main.async {
                    self.parent.workspace.timeParameter.value = .float(time)
                }
            } else {
                // Use the manual time value from the parameter
                if case .float(let manualTime) = parent.workspace.timeParameter.value {
                    time = manualTime
                }
            }
            
            // Use workspace resolution instead of drawable size for shader calculations
            var resolution = SIMD2<Float>(parent.workspace.renderWidth, parent.workspace.renderHeight)
            
            // Update workspace resolution parameter
            DispatchQueue.main.async {
                self.parent.workspace.resolutionParameter.value = .vector2(resolution.x, resolution.y)
            }
            
            // Get mouse position from workspace
            var mouse = mousePosition
            if case .vector2(let x, let y) = parent.workspace.mouseParameter.value {
                mouse = SIMD2<Float>(x, y)
            }
            
            // Set fragment shader uniforms
            encoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
            encoder.setFragmentBytes(&resolution, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
            encoder.setFragmentBytes(&mouse, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
            
            // Set custom parameters if any
            for (index, param) in parent.workspace.customParameters.enumerated() {
                let bufferIndex = index + 3  // Start after built-in parameters
                switch param.value {
                case .float(let val):
                    var value = val
                    encoder.setFragmentBytes(&value, length: MemoryLayout<Float>.size, index: bufferIndex)
                case .vector2(let x, let y):
                    var value = SIMD2<Float>(x, y)
                    encoder.setFragmentBytes(&value, length: MemoryLayout<SIMD2<Float>>.size, index: bufferIndex)
                case .vector3(let x, let y, let z):
                    var value = SIMD3<Float>(x, y, z)
                    encoder.setFragmentBytes(&value, length: MemoryLayout<SIMD3<Float>>.size, index: bufferIndex)
                case .vector4(let x, let y, let z, let w):
                    var value = SIMD4<Float>(x, y, z, w)
                    encoder.setFragmentBytes(&value, length: MemoryLayout<SIMD4<Float>>.size, index: bufferIndex)
                case .color(let r, let g, let b, let a):
                    var value = SIMD4<Float>(r, g, b, a)
                    encoder.setFragmentBytes(&value, length: MemoryLayout<SIMD4<Float>>.size, index: bufferIndex)
                case .int(let val):
                    var value = Int32(val)
                    encoder.setFragmentBytes(&value, length: MemoryLayout<Int32>.size, index: bufferIndex)
                case .bool(let val):
                    var value = val ? Int32(1) : Int32(0)
                    encoder.setFragmentBytes(&value, length: MemoryLayout<Int32>.size, index: bufferIndex)
                }
            }
            
            // Draw triangle strip
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
            
            // Track performance
            let startGPU = CACurrentMediaTime()
            commandBuffer.addCompletedHandler { _ in
                let gpuTime = (CACurrentMediaTime() - startGPU) * 1000.0
                DispatchQueue.main.async {
                    self.parent.workspace.renderer.gpuTime = gpuTime
                    self.parent.workspace.frameTime = gpuTime
                    self.parent.workspace.fps = 1000.0 / max(gpuTime, 0.001)
                }
            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
            
            // Store texture for export
            parent.workspace.renderer.currentTexture = drawable.texture
        }
        
        // Mouse tracking
        @objc func handleMouseMoved(_ event: NSEvent) {
            guard let view = event.window?.contentView else { return }
            let location = view.convert(event.locationInWindow, from: nil)
            let normalizedX = Float(location.x / view.bounds.width)
            let normalizedY = Float(1.0 - location.y / view.bounds.height)
            mousePosition = SIMD2<Float>(normalizedX, normalizedY)
            parent.workspace.mouseParameter.value = .vector2(normalizedX, normalizedY)
        }
    }
}

// MARK: - Shader Editor (from original)
struct ShaderEditorView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    // Use workspace selectedTabIndex directly instead of local state
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(Array(workspace.shaderTabs.enumerated()), id: \.offset) { index, tab in
                    ShaderTabView(
                        title: tab.title,
                        isSelected: workspace.selectedTabIndex == index
                    ) {
                        workspace.selectedTabIndex = index
                        workspace.scheduleCompilation()
                    }
                }
                
                Spacer()
                
                Button(action: workspace.addShaderTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
            .frame(height: 30)
            .background(Color(red: 0.13, green: 0.13, blue: 0.14))
            
            // Code editor - properly synchronized with WorkspaceManager
            MetalCodeEditor(
                text: Binding(
                    get: { 
                        // Ensure indices are valid
                        guard !workspace.shaderTabs.isEmpty,
                              workspace.selectedTabIndex >= 0,
                              workspace.selectedTabIndex < workspace.shaderTabs.count else {
                            return ""
                        }
                        return workspace.shaderTabs[workspace.selectedTabIndex].content
                    },
                    set: { newContent in
                        // Ensure indices are valid before setting
                        guard !workspace.shaderTabs.isEmpty,
                              workspace.selectedTabIndex >= 0,
                              workspace.selectedTabIndex < workspace.shaderTabs.count else {
                            return
                        }
                        workspace.shaderTabs[workspace.selectedTabIndex].content = newContent
                        workspace.markAsModified()
                        // Auto-compile on text change
                        workspace.scheduleCompilation()
                    }
                ),
                language: .metal,
                theme: .professional,
                onTextChange: { 
                    workspace.markAsModified() 
                    // Auto-compile on typing
                    workspace.scheduleCompilation()
                }
            )
            
            // Status bar
            HStack(spacing: 12) {
                // Compilation status
                CompilationStatusView()
                
                Spacer()
                
                // Line/column indicator
                Text("Ln \(workspace.cursorPosition.line), Col \(workspace.cursorPosition.column)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                
                // Language mode
                Text("Metal")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(Color(red: 0.12, green: 0.12, blue: 0.13))
        }
    }
}

// MARK: - Inspector View (from original)
struct InspectorView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var selectedSection = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Section selector
            Picker("", selection: $selectedSection) {
                Text("Parameters").tag(0)
                Text("Resolution").tag(1)
                Text("Export").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(12)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    switch selectedSection {
                    case 0:
                        ParametersSection()
                    case 1:
                        ResolutionSection()
                    case 2:
                        ExportSection()
                    default:
                        EmptyView()
                    }
                }
                .padding(12)
            }
        }
        .background(Color(red: 0.13, green: 0.13, blue: 0.14))
    }
}

// MARK: - Parameters Section (from original)
struct ParametersSection: View {
    @EnvironmentObject var workspace: WorkspaceManager
    
    private var builtInSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Built-in")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                ParameterRow(
                    parameter: workspace.timeParameter,
                    isBuiltin: true
                )
                
                ParameterRow(
                    parameter: workspace.resolutionParameter,
                    isBuiltin: true
                )
                
                ParameterRow(
                    parameter: workspace.mouseParameter,
                    isBuiltin: true
                )
            }
            .padding(8)
        }
    }
    
    private var customSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Custom")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Auto-extracted")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                ForEach(workspace.customParameters) { parameter in
                    ParameterRow(parameter: parameter, isBuiltin: false)
                }
                
                Button(action: { workspace.addCustomParameter() }) {
                    Label("Add Parameter", systemImage: "plus.circle")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(8)
        }
    }
    
    private var presetsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Presets")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Menu {
                        Button("Save Current", action: { workspace.savePreset() })
                        Divider()
                        ForEach(workspace.presets) { preset in
                            Button(preset.name) {
                                workspace.loadPreset(preset)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 11))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                }
                
                if workspace.presets.isEmpty {
                    Text("No presets saved")
                        .font(.system(size: 10))
                        .foregroundColor(Color.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach(workspace.presets) { preset in
                        PresetRow(preset: preset)
                    }
                }
            }
            .padding(8)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            builtInSection
            customSection
            presetsSection
        }
    }
}

// MARK: - Parameter Row (from original)
struct ParameterRow: View {
    let parameter: ShaderParameter
    let isBuiltin: Bool
    @EnvironmentObject var workspace: WorkspaceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(parameter.name)
                    .font(.system(size: 11, weight: .medium))
                
                Spacer()
                
                Text(parameter.formattedValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            switch parameter.type {
            case .float:
                Slider(
                    value: Binding(
                        get: { parameter.floatValue },
                        set: { workspace.updateParameter(parameter.id, value: $0) }
                    ),
                    in: parameter.range
                )
                .controlSize(.small)
                
            case .float2:
                HStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Text("X").font(.system(size: 9)).foregroundColor(.secondary)
                        Slider(
                            value: Binding(
                                get: { 
                                    if case .vector2(let x, _) = parameter.value { return x }
                                    return 0.0
                                },
                                set: { newX in
                                    if case .vector2(_, let y) = parameter.value {
                                        workspace.updateParameter(parameter.id, value: newX, isXComponent: true)
                                    }
                                }
                            ),
                            in: parameter.range
                        )
                        .controlSize(.mini)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Y").font(.system(size: 9)).foregroundColor(.secondary)
                        Slider(
                            value: Binding(
                                get: { 
                                    if case .vector2(_, let y) = parameter.value { return y }
                                    return 0.0
                                },
                                set: { newY in
                                    if case .vector2(let x, _) = parameter.value {
                                        workspace.updateParameter(parameter.id, value: newY, isYComponent: true)
                                    }
                                }
                            ),
                            in: parameter.range
                        )
                        .controlSize(.mini)
                    }
                }
                
            case .float3:
                VStack(spacing: 6) {
                    ColorPicker("", selection: Binding(
                        get: { parameter.colorValue },
                        set: { workspace.updateParameter(parameter.id, color: $0) }
                    ))
                    .labelsHidden()
                }
                
            case .int:
                Stepper(
                    value: Binding(
                        get: { parameter.intValue },
                        set: { workspace.updateParameter(parameter.id, intValue: $0) }
                    ),
                    in: Int(parameter.range.lowerBound)...Int(parameter.range.upperBound)
                ) {
                    EmptyView()
                }
                .controlSize(.small)
                
            case .bool:
                Toggle("", isOn: Binding(
                    get: { parameter.boolValue },
                    set: { workspace.updateParameter(parameter.id, boolValue: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                
            case .float4:
                VStack(spacing: 6) {
                    Text("Float4 not implemented")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
            case .color:
                ColorPicker("", selection: Binding(
                    get: { parameter.colorValue },
                    set: { workspace.updateParameter(parameter.id, color: $0) }
                ))
                .labelsHidden()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Other UI Components
struct PerformanceIndicator: View {
    @EnvironmentObject var workspace: WorkspaceManager
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(Int(workspace.fps)) FPS")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(workspace.fps >= 60 ? .green : workspace.fps >= 30 ? .orange : .red)
            
            Text("\(String(format: "%.1f", workspace.frameTime))ms")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

struct PerformanceOverlay: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var showMobileEstimates = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FPS: \(Int(workspace.fps))")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(workspace.fps >= 60 ? .green : .orange)
            
            Text("Frame: \(String(format: "%.2f", workspace.frameTime))ms")
                .font(.system(size: 10, design: .monospaced))
            
            Text("GPU: \(String(format: "%.2f", workspace.renderer?.gpuTime ?? 0.0))ms")
                .font(.system(size: 10, design: .monospaced))
            
            Divider()
                .padding(.vertical, 2)
            
            // iPhone Performance Predictions
            Button(action: { showMobileEstimates.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: showMobileEstimates ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                    Text("iPhone Performance")
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.white.opacity(0.8))
            
            if showMobileEstimates {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(iPhonePerformanceEstimates, id: \.model) { estimate in
                        HStack {
                            Text(estimate.model)
                                .font(.system(size: 9, design: .monospaced))
                                .frame(width: 70, alignment: .leading)
                            
                            Text("\(estimate.estimatedFPS) FPS")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(performanceColor(for: estimate.estimatedFPS))
                            
                            if estimate.estimatedFPS < 30 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .padding(.leading, 12)
                .padding(.top, 4)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
        .cornerRadius(6)
        .foregroundColor(.white)
    }
    
    private var iPhonePerformanceEstimates: [(model: String, estimatedFPS: Int)] {
        // Calculate estimates based on current Mac performance
        // These are rough estimates based on relative GPU power
        let currentFPS = workspace.fps
        let frameTime = workspace.frameTime
        
        // Baseline: if Mac gets 60 FPS, these are typical mobile equivalents
        // Adjust based on shader complexity
        let complexityFactor = getShaderComplexityFactor()
        
        return [
            (model: "iPhone 15 Pro", estimatedFPS: estimateFPS(baseFPS: currentFPS, factor: 0.75 * complexityFactor)),
            (model: "iPhone 15", estimatedFPS: estimateFPS(baseFPS: currentFPS, factor: 0.60 * complexityFactor)),
            (model: "iPhone 14 Pro", estimatedFPS: estimateFPS(baseFPS: currentFPS, factor: 0.65 * complexityFactor)),
            (model: "iPhone 14", estimatedFPS: estimateFPS(baseFPS: currentFPS, factor: 0.55 * complexityFactor)),
            (model: "iPhone 13", estimatedFPS: estimateFPS(baseFPS: currentFPS, factor: 0.50 * complexityFactor)),
            (model: "iPhone 12", estimatedFPS: estimateFPS(baseFPS: currentFPS, factor: 0.40 * complexityFactor)),
            (model: "iPhone SE 3", estimatedFPS: estimateFPS(baseFPS: currentFPS, factor: 0.45 * complexityFactor))
        ]
    }
    
    private func estimateFPS(baseFPS: Double, factor: Double) -> Int {
        let estimated = baseFPS * factor
        // Cap at 60 FPS (typical mobile display refresh)
        return Int(min(60, max(1, estimated)))
    }
    
    private func getShaderComplexityFactor() -> Double {
        // Analyze shader complexity based on compilation and runtime metrics
        let frameTime = workspace.frameTime
        
        if frameTime < 5 {
            return 1.0  // Simple shader
        } else if frameTime < 10 {
            return 0.85  // Moderate complexity
        } else if frameTime < 16 {
            return 0.7  // Complex shader
        } else {
            return 0.5  // Very complex shader
        }
    }
    
    private func performanceColor(for fps: Int) -> Color {
        if fps >= 60 {
            return .green
        } else if fps >= 30 {
            return .yellow
        } else if fps >= 15 {
            return .orange
        } else {
            return .red
        }
    }
}

struct CompilationStatusView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            if workspace.compilationStatus == .compiling {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
        }
    }
    
    private var statusColor: Color {
        switch workspace.compilationStatus {
        case .ready: return .gray
        case .idle: return .gray
        case .compiling: return .orange
        case .success: return .green
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch workspace.compilationStatus {
        case .ready: return "Ready"
        case .idle: return "Idle"
        case .compiling: return "Compiling..."
        case .success: return "Compiled"
        case .error: return "\(workspace.compilationErrors.count) errors"
        }
    }
}

struct ConsoleView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CONSOLE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { workspace.compilationErrors.removeAll() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.3))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(workspace.compilationErrors, id: \.message) { error in
                        HStack(alignment: .top, spacing: 8) {
                            let isError = error.severity == .error
                            let iconName = isError ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
                            let iconColor = isError ? Color.red : Color.orange
                            
                            Image(systemName: iconName)
                                .font(.system(size: 11))
                                .foregroundColor(iconColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(error.message)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                                
                                Text("Line \(error.line), Column \(error.column)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(4)
                    }
                }
                .padding(12)
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.11))
    }
}

struct ResolutionSection: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var widthText: String = "1920"
    @State private var heightText: String = "1080"
    @State private var selectedPreset = "Custom"
    @State private var showWarning = false
    
    let resolutionPresets = [
        ("Custom", 0, 0),
        ("720p", 1280, 720),
        ("1080p", 1920, 1080),
        ("1440p", 2560, 1440),
        ("4K", 3840, 2160),
        ("Square (1:1)", 1080, 1080),
        ("Vertical (9:16)", 1080, 1920),
        ("Instagram", 1080, 1350)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Text("Viewport Resolution").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)) {
                VStack(alignment: .leading, spacing: 12) {
                    // Current resolution display
                    HStack {
                        Text("Current:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("\(Int(workspace.renderWidth))×\(Int(workspace.renderHeight))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("Aspect: \(aspectRatioString)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Preset selector
                    Picker("Preset", selection: $selectedPreset) {
                        ForEach(resolutionPresets, id: \.0) { preset in
                            Text(preset.0).tag(preset.0)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedPreset) { _, newValue in
                        if let preset = resolutionPresets.first(where: { $0.0 == newValue }) {
                            if preset.1 > 0 && preset.2 > 0 {
                                widthText = "\(preset.1)"
                                heightText = "\(preset.2)"
                            }
                        }
                    }
                    
                    // Custom input fields
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Width")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            TextField("Width", text: $widthText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .onChange(of: widthText) { _, _ in
                                    selectedPreset = "Custom"
                                }
                        }
                        
                        Text("×")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Height")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            TextField("Height", text: $heightText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .onChange(of: heightText) { _, _ in
                                    selectedPreset = "Custom"
                                }
                        }
                    }
                    
                    // Apply button
                    HStack {
                        Button("Apply") {
                            applyResolution()
                        }
                        .controlSize(.small)
                        .disabled(!isValidResolution)
                        
                        if !isValidResolution {
                            Text("Invalid resolution")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }
                    
                    if showWarning {
                        Text("⚠️ Changing resolution will restart the shader")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                .padding(8)
            }
            
            // Performance tips
            GroupBox(label: Text("Performance").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        Text("Higher resolutions may impact performance")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Recommended maximum: 3840×2160 (4K)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
        }
        .onAppear {
            widthText = "\(Int(workspace.renderWidth))"
            heightText = "\(Int(workspace.renderHeight))"
        }
    }
    
    var aspectRatioString: String {
        let ratio = workspace.renderWidth / workspace.renderHeight
        if abs(ratio - 16.0/9.0) < 0.01 { return "16:9" }
        if abs(ratio - 4.0/3.0) < 0.01 { return "4:3" }
        if abs(ratio - 1.0) < 0.01 { return "1:1" }
        if abs(ratio - 9.0/16.0) < 0.01 { return "9:16" }
        return String(format: "%.2f:1", ratio)
    }
    
    var isValidResolution: Bool {
        guard let width = Int(widthText), let height = Int(heightText) else { return false }
        return width > 0 && width <= 8192 && height > 0 && height <= 8192
    }
    
    func applyResolution() {
        guard let width = Int(widthText), let height = Int(heightText) else { return }
        showWarning = true
        workspace.updateResolution(width: Float(width), height: Float(height))
        workspace.restartShader()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showWarning = false
        }
    }
}

struct TexturesSection: View {
    @State private var textures: [LoadedTexture] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(textures) { texture in
                HStack {
                    Image(nsImage: texture.thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .background(CheckerboardBackground())
                        .cornerRadius(4)
                    
                    VStack(alignment: .leading) {
                        Text(texture.name)
                            .font(.system(size: 11))
                        Text("\(texture.width)×\(texture.height)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { removeTexture(texture) }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.black.opacity(0.2))
                .cornerRadius(6)
            }
            
            Button(action: loadTexture) {
                Label("Load Texture", systemImage: "photo")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
        }
    }
    
    private func loadTexture() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.begin { response in
            if response == .OK, let _ = panel.url {
                // Load texture
            }
        }
    }
    
    private func removeTexture(_ texture: LoadedTexture) {
        textures.removeAll { $0.id == texture.id }
    }
}

struct LoadedTexture: Identifiable {
    let id = UUID()
    let name: String
    let thumbnail: NSImage
    let width: Int
    let height: Int
}

struct ExportSection: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var exportFormat = "PNG"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Image Export
            GroupBox(label: Text("Image").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Format", selection: $exportFormat) {
                        Text("PNG").tag("PNG")
                        Text("JPEG").tag("JPEG")
                        Text("TIFF").tag("TIFF")
                    }
                    .pickerStyle(.menu)
                    
                    Text("Resolution: \(Int(workspace.renderWidth))×\(Int(workspace.renderHeight))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Button("Export Image") {
                        workspace.exportImage()
                    }
                    .controlSize(.small)
                }
                .padding(8)
            }
            
            // Video Export
            GroupBox(label: Text("Video").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Duration (sec):")
                            .font(.system(size: 11))
                        TextField("", value: Binding(
                            get: { workspace.videoDuration },
                            set: { workspace.videoDuration = $0 }
                        ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                    
                    HStack {
                        Text("FPS:")
                            .font(.system(size: 11))
                        TextField("", value: Binding(
                            get: { workspace.videoFPS },
                            set: { workspace.videoFPS = $0 }
                        ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                    
                    if workspace.isExportingVideo {
                        VStack(spacing: 8) {
                            ProgressView(value: workspace.exportProgress)
                                .progressViewStyle(.linear)
                            
                            HStack {
                                Text("Exporting... \(Int(workspace.exportProgress * 100))%")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("Cancel") {
                                    workspace.cancelVideoExport()
                                }
                                .controlSize(.mini)
                            }
                        }
                    } else {
                        Button("Export Video") {
                            workspace.exportVideo()
                        }
                        .controlSize(.small)
                    }
                }
                .padding(8)
            }
            
            // Code Export
            GroupBox(label: Text("Code").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)) {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Export Shader Code") {
                        workspace.exportCode()
                    }
                    .controlSize(.small)
                }
                .padding(8)
            }
        }
    }
}

struct CheckerboardBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let tileSize: CGFloat = 10
                let rows = Int(size.height / tileSize) + 1
                let cols = Int(size.width / tileSize) + 1
                
                for row in 0..<rows {
                    for col in 0..<cols {
                        let isEven = (row + col) % 2 == 0
                        let rect = CGRect(
                            x: CGFloat(col) * tileSize,
                            y: CGFloat(row) * tileSize,
                            width: tileSize,
                            height: tileSize
                        )
                        context.fill(
                            Path(rect),
                            with: .color(isEven ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                        )
                    }
                }
            }
        }
    }
}

struct ShaderTabView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)
                .background(isSelected ? Color(red: 0.15, green: 0.15, blue: 0.16) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

struct PresetRow: View {
    let preset: ShaderPreset
    @EnvironmentObject var workspace: WorkspaceManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.system(size: 11))
                
                Text(preset.timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { workspace.loadPreset(preset) }) {
                Text("Load")
                    .font(.system(size: 10))
            }
            .controlSize(.mini)
        }
        .padding(6)
        .background(Color.black.opacity(0.2))
        .cornerRadius(4)
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .accentColor : .secondary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Split Views
struct HSplitView: View {
    let children: [AnyView]
    
    init<V0: View, V1: View>(@ViewBuilder content: () -> TupleView<(V0, V1)>) {
        let tuple = content().value
        self.children = [AnyView(tuple.0), AnyView(tuple.1)]
    }
    
    init<V0: View, V1: View, V2: View>(@ViewBuilder content: () -> TupleView<(V0, V1, V2)>) {
        let tuple = content().value
        self.children = [AnyView(tuple.0), AnyView(tuple.1), AnyView(tuple.2)]
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<children.count, id: \.self) { index in
                    children[index]
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if index < children.count - 1 {
                        Divider()
                            .background(Color.black.opacity(0.5))
                    }
                }
            }
        }
    }
}

struct VSplitView: View {
    let children: [AnyView]
    
    init<V0: View, V1: View>(@ViewBuilder content: () -> TupleView<(V0, V1)>) {
        let tuple = content().value
        self.children = [AnyView(tuple.0), AnyView(tuple.1)]
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ForEach(0..<children.count, id: \.self) { index in
                    children[index]
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if index < children.count - 1 {
                        Divider()
                            .background(Color.black.opacity(0.5))
                    }
                }
            }
        }
    }
}

// MARK: - Guide Content Components
struct ShaderLibraryGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Shader Library")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Browse and load pre-built shaders to learn from and modify.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Divider()
            
            GuideFeature(
                icon: "magnifyingglass",
                title: "Search & Filter",
                description: "Search by name or filter by category to find specific shader types"
            )
            
            GuideFeature(
                icon: "speedometer",
                title: "Performance Metrics",
                description: "Each shader shows estimated FPS and complexity level"
            )
            
            GuideFeature(
                icon: "hand.tap",
                title: "Interactive Shaders",
                description: "Look for the hand icon to find shaders with mouse interaction"
            )
            
            GuideFeature(
                icon: "doc.on.doc",
                title: "Learn by Example",
                description: "Load any shader to see its code and modify it for your needs"
            )
        }
    }
}

struct ParametersGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Shader Parameters")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Control shader behavior in real-time with adjustable parameters.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                GuideFeature(
                    icon: "slider.horizontal.3",
                    title: "Built-in Parameters",
                    description: "Time, resolution, and mouse position are always available"
                )
                
                GuideFeature(
                    icon: "wand.and.stars",
                    title: "Auto-extraction",
                    description: "Click the magic wand to extract parameters from shader code"
                )
                
                GuideFeature(
                    icon: "plus.circle",
                    title: "Custom Parameters",
                    description: "Add your own parameters with various types (float, int, color)"
                )
                
                GuideFeature(
                    icon: "square.stack",
                    title: "Presets",
                    description: "Save and load parameter combinations as presets"
                )
            }
        }
    }
}

struct EditorPreviewGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Editor & Live Preview")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Write Metal shader code and see results instantly.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                GuideFeature(
                    icon: "keyboard",
                    title: "Code Editor",
                    description: "Full-featured editor with syntax highlighting and auto-completion"
                )
                
                GuideFeature(
                    icon: "bolt.fill",
                    title: "Auto-Compilation",
                    description: "Shaders compile automatically as you type - no manual build needed"
                )
                
                GuideFeature(
                    icon: "eye",
                    title: "60+ FPS Preview",
                    description: "Professional-grade real-time rendering at high frame rates"
                )
                
                GuideFeature(
                    icon: "exclamationmark.triangle",
                    title: "Error Highlighting",
                    description: "Compilation errors show inline with helpful messages"
                )
            }
            
            // Keyboard shortcuts
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard Shortcuts:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        KeyboardShortcut(key: "⌘B", action: "Compile")
                        KeyboardShortcut(key: "⌘S", action: "Save")
                        KeyboardShortcut(key: "⌘N", action: "New Shader")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        KeyboardShortcut(key: "Space", action: "Play/Pause")
                        KeyboardShortcut(key: "⌘⇧R", action: "Reset Parameters")
                        KeyboardShortcut(key: "⌘Z", action: "Undo")
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.5))
                .cornerRadius(6)
            }
        }
    }
}

struct KeyboardShortcut: View {
    let key: String
    let action: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(minWidth: 40, alignment: .trailing)
            Text(action)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

struct MouseInteractionGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Mouse Interaction")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Interactive shaders respond to mouse movement and clicks.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                GuideFeature(
                    icon: "cursorarrow.rays",
                    title: "Position Tracking",
                    description: "Mouse position is automatically sent to shaders as a uniform"
                )
                
                GuideFeature(
                    icon: "hand.tap",
                    title: "Click & Drag",
                    description: "Press and drag to interact with shader effects"
                )
                
                GuideFeature(
                    icon: "target",
                    title: "Visual Feedback",
                    description: "Crosshairs and coordinates show exact mouse position"
                )
                
                GuideFeature(
                    icon: "waveform.circle",
                    title: "Ripple Effects",
                    description: "Many shaders create ripples or distortions at mouse position"
                )
            }
            
            // Code example
            VStack(alignment: .leading, spacing: 8) {
                Text("Using Mouse in Shaders:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                
                Text("""
                // In your shader uniforms:
                float2 mouse;  // Normalized 0-1
                
                // Calculate distance to mouse:
                float dist = length(uv - uniforms.mouse);
                
                // Create mouse effects:
                color *= 1.0 - smoothstep(0.0, 0.5, dist);
                """)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - Extensions
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}