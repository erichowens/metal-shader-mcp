import SwiftUI
import MetalKit
import AppKit

// MARK: - Main App Structure
@main
struct MetalStudioApp: App {
    var body: some Scene {
        WindowGroup {
            MetalStudioView()
                .frame(minWidth: 1400, minHeight: 800)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1600, height: 900)
    }
}

// MARK: - Main View with Split Panes
struct MetalStudioView: View {
    @StateObject private var viewModel = MetalViewModel()
    @State private var leftPaneWidth: CGFloat = 380
    @State private var rightPaneWidth: CGFloat = 360
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Pane - Code Editor
                ShaderEditorPane(viewModel: viewModel)
                    .frame(width: leftPaneWidth)
                    .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                    .frame(width: 4)
                    .background(Color.black.opacity(0.5))
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newWidth = leftPaneWidth + value.translation.width
                                leftPaneWidth = min(max(newWidth, 300), 500)
                            }
                    )
                
                // Center Pane - Metal Preview
                MetalPreviewPane(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.95))
                
                Divider()
                    .frame(width: 4)
                    .background(Color.black.opacity(0.5))
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newWidth = rightPaneWidth - value.translation.width
                                rightPaneWidth = min(max(newWidth, 280), 450)
                            }
                    )
                
                // Right Pane - Controls
                ControlsPane(viewModel: viewModel)
                    .frame(width: rightPaneWidth)
                    .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .background(Color.black)
    }
}

// MARK: - Shader Editor Pane
struct ShaderEditorPane: View {
    @ObservedObject var viewModel: MetalViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor Header
            HStack {
                Text("SHADER CODE")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Picker("", selection: $selectedTab) {
                    Text("Fragment").tag(0)
                    Text("Vertex").tag(1)
                    Text("Compute").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 180)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.3))
            
            // Code Editor
            ShaderTextEditor(
                text: selectedTab == 0 ? $viewModel.fragmentShader : 
                      selectedTab == 1 ? $viewModel.vertexShader : 
                      $viewModel.computeShader,
                onCompile: { viewModel.compileShaders() }
            )
            .font(.system(size: 13, design: .monospaced))
            
            // Compilation Status Bar
            HStack {
                Circle()
                    .fill(viewModel.compilationStatus == .success ? Color.green : 
                          viewModel.compilationStatus == .error ? Color.red : 
                          Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.statusMessage)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { viewModel.compileShaders() }) {
                    Label("Compile", systemImage: "hammer.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.3))
        }
    }
}

// MARK: - Metal Preview Pane
struct MetalPreviewPane: View {
    @ObservedObject var viewModel: MetalViewModel
    @State private var previewSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Checkerboard background
                CheckerboardPattern()
                
                // Metal View Container
                let size = min(geometry.size.width * 0.9, geometry.size.height * 0.9)
                
                VStack {
                    Spacer()
                    
                    ZStack(alignment: .topLeading) {
                        // Metal Rendering View
                        MetalRenderView(viewModel: viewModel)
                            .frame(width: size, height: size)
                            .background(Color.black)
                            .border(Color.white.opacity(0.2), width: 1)
                            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                        
                        // FPS Overlay
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FPS: \(viewModel.currentFPS, specifier: "%.0f")")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            Text("Frame: \(viewModel.frameCount)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                            Text("\(Int(size))×\(Int(size))")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                        .padding(12)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Preview Controls Overlay
                VStack {
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: { viewModel.resetAnimation() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { viewModel.toggleAnimation() }) {
                            Image(systemName: viewModel.isAnimating ? "pause.fill" : "play.fill")
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { viewModel.captureFrame() }) {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.bottom, 20)
                }
            }
            .onAppear {
                previewSize = geometry.size
            }
            .onChange(of: geometry.size) { newSize in
                previewSize = newSize
            }
        }
    }
}

// MARK: - Controls Pane
struct ControlsPane: View {
    @ObservedObject var viewModel: MetalViewModel
    @State private var selectedControlTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Controls Header
            HStack {
                Text("PARAMETERS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: { viewModel.resetParameters() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.3))
            
            // Parameters Section
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Time Parameter
                    ParameterControl(
                        label: "Time",
                        value: $viewModel.time,
                        range: 0...10,
                        step: 0.01
                    )
                    
                    // Mouse Position
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mouse Position")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack {
                            ParameterControl(
                                label: "X",
                                value: $viewModel.mouseX,
                                range: -1...1,
                                step: 0.01
                            )
                            ParameterControl(
                                label: "Y",
                                value: $viewModel.mouseY,
                                range: -1...1,
                                step: 0.01
                            )
                        }
                    }
                    
                    // Color Parameter
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base Color")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        
                        ColorPicker("", selection: $viewModel.baseColor)
                            .labelsHidden()
                    }
                    
                    // Custom Parameters
                    ForEach(viewModel.customParameters) { param in
                        ParameterControl(
                            label: param.name,
                            value: Binding(
                                get: { param.value },
                                set: { viewModel.updateParameter(param.id, value: $0) }
                            ),
                            range: param.range,
                            step: param.step
                        )
                    }
                    
                    Button(action: { viewModel.addCustomParameter() }) {
                        Label("Add Parameter", systemImage: "plus.circle")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
                .padding(12)
            }
            
            Divider()
            
            // MCP Tools Section
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("MCP TOOLS")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Circle()
                        .fill(viewModel.mcpConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                
                MCPToolsView(viewModel: viewModel)
                    .frame(maxHeight: 200)
            }
        }
    }
}

// MARK: - Supporting Views
struct ShaderTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onCompile: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        textView.string = text
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = NSColor(white: 0.08, alpha: 1.0)
        textView.textColor = NSColor(white: 0.9, alpha: 1.0)
        textView.insertionPointColor = .white
        textView.delegate = context.coordinator
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ShaderTextEditor
        
        init(_ parent: ShaderTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                textView.insertText("    ", replacementRange: textView.selectedRange())
                return true
            }
            if commandSelector == NSSelectorFromString("insertNewline:") && NSEvent.modifierFlags.contains(.command) {
                parent.onCompile()
                return true
            }
            return false
        }
    }
}

struct MetalRenderView: NSViewRepresentable {
    @ObservedObject var viewModel: MetalViewModel
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        context.coordinator.setupMetal(device: mtkView.device!)
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.viewModel = viewModel
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var viewModel: MetalViewModel
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var pipelineState: MTLRenderPipelineState?
        var startTime: Date = Date()
        var lastFrameTime: Date = Date()
        var frameCount: Int = 0
        
        init(viewModel: MetalViewModel) {
            self.viewModel = viewModel
            super.init()
        }
        
        func setupMetal(device: MTLDevice) {
            self.device = device
            self.commandQueue = device.makeCommandQueue()
            compilePipeline()
        }
        
        func compilePipeline() {
            // Compile shaders and create pipeline state
            // Implementation would compile viewModel.fragmentShader and viewModel.vertexShader
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle size changes
        }
        
        func draw(in view: MTKView) {
            frameCount += 1
            let currentTime = Date()
            let deltaTime = currentTime.timeIntervalSince(lastFrameTime)
            
            // Update FPS
            if deltaTime > 0 {
                viewModel.currentFPS = 1.0 / deltaTime
            }
            viewModel.frameCount = frameCount
            
            // Update time uniform
            viewModel.time = Float(currentTime.timeIntervalSince(startTime))
            
            lastFrameTime = currentTime
            
            // Render frame
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor else { return }
            
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            
            let commandBuffer = commandQueue.makeCommandBuffer()!
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
            
            // Render operations would go here
            
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

struct ParameterControl: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(String(format: "%.3f", value))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
        }
    }
}

struct CheckerboardPattern: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let tileSize: CGFloat = 20
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
                            with: .color(isEven ? Color.white.opacity(0.03) : Color.black.opacity(0.03))
                        )
                    }
                }
            }
        }
    }
}

struct MCPToolsView: View {
    @ObservedObject var viewModel: MetalViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // MCP Connection Status
                HStack {
                    Image(systemName: viewModel.mcpConnected ? "link.circle.fill" : "link.circle")
                        .foregroundColor(viewModel.mcpConnected ? .green : .red)
                    
                    Text(viewModel.mcpConnected ? "Connected" : "Disconnected")
                        .font(.system(size: 11))
                    
                    Spacer()
                    
                    Button(action: { viewModel.toggleMCPConnection() }) {
                        Text(viewModel.mcpConnected ? "Disconnect" : "Connect")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
                
                if viewModel.mcpConnected {
                    // Available Tools
                    Text("Available Tools")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    
                    ForEach(viewModel.mcpTools, id: \.self) { tool in
                        HStack {
                            Image(systemName: "wrench.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                            
                            Text(tool)
                                .font(.system(size: 10))
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(12)
        }
    }
}

// MARK: - View Model
class MetalViewModel: ObservableObject {
    @Published var fragmentShader = defaultFragmentShader
    @Published var vertexShader = defaultVertexShader
    @Published var computeShader = defaultComputeShader
    
    @Published var compilationStatus: CompilationStatus = .ready
    @Published var statusMessage = "Ready"
    
    @Published var time: Float = 0
    @Published var mouseX: Float = 0
    @Published var mouseY: Float = 0
    @Published var baseColor = Color.blue
    
    @Published var currentFPS: Double = 60
    @Published var frameCount: Int = 0
    @Published var isAnimating = true
    
    @Published var customParameters: [ShaderParameter] = []
    
    @Published var mcpConnected = false
    @Published var mcpTools = ["shader-optimizer", "texture-loader", "mesh-generator"]
    
    enum CompilationStatus {
        case ready, compiling, success, error
    }
    
    func compileShaders() {
        compilationStatus = .compiling
        statusMessage = "Compiling..."
        
        // Simulate compilation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.compilationStatus = .success
            self?.statusMessage = "Compilation successful"
        }
    }
    
    func resetAnimation() {
        time = 0
        frameCount = 0
    }
    
    func toggleAnimation() {
        isAnimating.toggle()
    }
    
    func captureFrame() {
        // Capture current frame
    }
    
    func resetParameters() {
        time = 0
        mouseX = 0
        mouseY = 0
        baseColor = .blue
        customParameters.removeAll()
    }
    
    func addCustomParameter() {
        let newParam = ShaderParameter(
            id: UUID(),
            name: "Custom \(customParameters.count + 1)",
            value: 0.5,
            range: 0...1,
            step: 0.01
        )
        customParameters.append(newParam)
    }
    
    func updateParameter(_ id: UUID, value: Float) {
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
            customParameters[index].value = value
        }
    }
    
    func toggleMCPConnection() {
        mcpConnected.toggle()
    }
}

struct ShaderParameter: Identifiable {
    let id: UUID
    var name: String
    var value: Float
    var range: ClosedRange<Float>
    var step: Float
}

// MARK: - Default Shaders
let defaultFragmentShader = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant float &time [[buffer(0)]],
                               constant float2 &mouse [[buffer(1)]]) {
    float2 uv = in.texCoord;
    
    // Animated gradient with mouse interaction
    float3 color = 0.5 + 0.5 * cos(time + uv.xyx + float3(0, 2, 4));
    color *= length(uv - mouse) * 2.0;
    
    return float4(color, 1.0);
}
"""

let defaultVertexShader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 1.0);
    out.texCoord = in.texCoord;
    return out;
}
"""

let defaultComputeShader = """
#include <metal_stdlib>
using namespace metal;

kernel void computeShader(texture2d<float, access::write> output [[texture(0)]],
                         uint2 gid [[thread_position_in_grid]],
                         constant float &time [[buffer(0)]]) {
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
    float3 color = 0.5 + 0.5 * cos(time + uv.xyx + float3(0, 2, 4));
    output.write(float4(color, 1.0), gid);
}
"""