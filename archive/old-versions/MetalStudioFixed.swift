import SwiftUI
import MetalKit
import AppKit

@main
struct MetalStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 700)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct ContentView: View {
    @StateObject private var renderer = MetalRenderer()
    @State private var shaderCode = defaultFragmentShader
    @State private var editorWidth: CGFloat = 400
    @State private var inspectorWidth: CGFloat = 320
    @State private var compilationStatus = "Ready"
    @State private var timeValue: Float = 0
    @State private var speedValue: Float = 1.0
    @State private var colorIntensity: Float = 1.0
    @State private var waveFrequency: Float = 20.0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Panel - Code Editor
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("SHADER CODE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Compile") {
                            compileShader()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(Color(white: 0.1))
                    
                    // Editor
                    ShaderEditor(text: $shaderCode)
                        .font(.system(size: 13, design: .monospaced))
                    
                    // Status Bar
                    HStack {
                        Circle()
                            .fill(compilationStatus == "Success" ? Color.green : 
                                  compilationStatus == "Error" ? Color.red : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(compilationStatus)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(white: 0.08))
                }
                .frame(width: editorWidth)
                
                // Divider
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 1)
                
                // Center - Preview
                ZStack {
                    // Checkerboard background
                    CheckerPattern()
                    
                    // Metal View
                    MetalView(renderer: renderer)
                        .aspectRatio(1.0, contentMode: .fit)
                        .frame(maxWidth: min(geometry.size.width * 0.6, geometry.size.height * 0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(radius: 20)
                    
                    // FPS Overlay
                    VStack {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("60 FPS")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.green)
                                Text("Frame: \(Int(timeValue * 60))")
                                    .font(.system(size: 10, design: .monospaced))
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(6)
                            
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding()
                }
                .background(Color(white: 0.05))
                
                // Right Panel - Controls
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("PARAMETERS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(white: 0.1))
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Time Control
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Time")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Text(String(format: "%.2f", timeValue))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: $timeValue, in: 0...10) { _ in
                                    renderer.updateTime(timeValue)
                                }
                                .controlSize(.small)
                            }
                            
                            // Speed Control
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Speed")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Text(String(format: "%.1fx", speedValue))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: $speedValue, in: 0...5) { _ in
                                    renderer.updateSpeed(speedValue)
                                }
                                .controlSize(.small)
                            }
                            
                            // Color Intensity
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Color Intensity")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Text(String(format: "%.0f%%", colorIntensity * 100))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: $colorIntensity, in: 0...2) { _ in
                                    renderer.updateColorIntensity(colorIntensity)
                                }
                                .controlSize(.small)
                            }
                            
                            // Wave Frequency
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Wave Frequency")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Text(String(format: "%.0f", waveFrequency))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: $waveFrequency, in: 1...50) { _ in
                                    renderer.updateWaveFrequency(waveFrequency)
                                }
                                .controlSize(.small)
                            }
                            
                            Divider()
                            
                            // Playback Controls
                            HStack(spacing: 12) {
                                Button(action: { renderer.resetAnimation() }) {
                                    Image(systemName: "backward.end.fill")
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { renderer.togglePlayback() }) {
                                    Image(systemName: renderer.isPlaying ? "pause.fill" : "play.fill")
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { captureFrame() }) {
                                    Image(systemName: "camera.fill")
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.system(size: 16))
                            
                            Divider()
                            
                            // MCP Status
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    
                                    Text("MCP Server Ready")
                                        .font(.system(size: 11))
                                    
                                    Spacer()
                                }
                                
                                Text("Port: 3000")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color(white: 0.08))
                            .cornerRadius(6)
                        }
                        .padding(12)
                    }
                    
                    Spacer()
                }
                .frame(width: inspectorWidth)
            }
        }
        .background(Color(white: 0.06))
        .onAppear {
            renderer.start()
        }
    }
    
    func compileShader() {
        compilationStatus = "Compiling..."
        
        renderer.compileShader(shaderCode) { success in
            compilationStatus = success ? "Success" : "Error"
        }
    }
    
    func captureFrame() {
        // Capture current frame
    }
}

// MARK: - Shader Editor
struct ShaderEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.backgroundColor = NSColor(white: 0.08, alpha: 1)
        textView.textColor = NSColor(white: 0.9, alpha: 1)
        textView.insertionPointColor = .white
        textView.delegate = context.coordinator
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ShaderEditor
        
        init(_ parent: ShaderEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Metal View
struct MetalView: NSViewRepresentable {
    let renderer: MetalRenderer
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = renderer.device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.delegate = renderer
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {}
}

// MARK: - Metal Renderer
class MetalRenderer: NSObject, ObservableObject {
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    
    @Published var isPlaying = true
    private var startTime = Date()
    private var currentTime: Float = 0
    private var speed: Float = 1.0
    private var colorIntensity: Float = 1.0
    private var waveFrequency: Float = 20.0
    
    struct ShaderUniforms {
        var time: Float = 0
        var resolution: SIMD2<Float> = SIMD2<Float>(800, 800)
        var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
        var colorIntensity: Float = 1.0
        var waveFrequency: Float = 20.0
    }
    
    private var uniforms = ShaderUniforms()
    
    override init() {
        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        
        compileDefaultShader()
    }
    
    func start() {
        startTime = Date()
    }
    
    private func compileDefaultShader() {
        let source = simpleVertexShader + "\n\n" + defaultFragmentShader
        
        do {
            let library = try device.makeLibrary(source: source, options: nil)
            let vertexFunction = library.makeFunction(name: "vertexShader")
            let fragmentFunction = library.makeFunction(name: "fragmentShader")
            
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Shader compilation failed: \(error)")
        }
    }
    
    func compileShader(_ source: String, completion: @escaping (Bool) -> Void) {
        let fullSource = simpleVertexShader + "\n\n" + source
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let library = try self.device.makeLibrary(source: fullSource, options: nil)
                let vertexFunction = library.makeFunction(name: "vertexShader")
                let fragmentFunction = library.makeFunction(name: "fragmentShader")
                
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = vertexFunction
                descriptor.fragmentFunction = fragmentFunction
                descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                
                let newPipeline = try self.device.makeRenderPipelineState(descriptor: descriptor)
                
                DispatchQueue.main.async {
                    self.pipelineState = newPipeline
                    completion(true)
                }
            } catch {
                print("Compilation error: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    func updateTime(_ time: Float) {
        currentTime = time
    }
    
    func updateSpeed(_ speed: Float) {
        self.speed = speed
    }
    
    func updateColorIntensity(_ intensity: Float) {
        colorIntensity = intensity
    }
    
    func updateWaveFrequency(_ frequency: Float) {
        waveFrequency = frequency
    }
    
    func resetAnimation() {
        startTime = Date()
        currentTime = 0
    }
    
    func togglePlayback() {
        isPlaying.toggle()
    }
}

// MARK: - MTKViewDelegate
extension MetalRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState else { return }
        
        // Update time
        if isPlaying {
            currentTime = Float(Date().timeIntervalSince(startTime)) * speed
        }
        uniforms.time = currentTime
        uniforms.colorIntensity = colorIntensity
        uniforms.waveFrequency = waveFrequency
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        
        encoder.setRenderPipelineState(pipelineState)
        
        // Set uniforms
        var uniformData = uniforms
        encoder.setFragmentBytes(&uniformData, length: MemoryLayout<ShaderUniforms>.size, index: 0)
        
        // Draw full-screen triangle
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - UI Components
struct CheckerPattern: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let tileSize: CGFloat = 20
                let rows = Int(size.height / tileSize) + 1
                let cols = Int(size.width / tileSize) + 1
                
                for row in 0..<rows {
                    for col in 0..<cols {
                        let isEven = (row + col) % 2 == 0
                        let rect = CGRect(x: CGFloat(col) * tileSize,
                                        y: CGFloat(row) * tileSize,
                                        width: tileSize,
                                        height: tileSize)
                        context.fill(Path(rect),
                                   with: .color(isEven ? Color.white.opacity(0.03) : Color.black.opacity(0.03)))
                    }
                }
            }
        }
    }
}

// MARK: - Shader Sources
let simpleVertexShader = """
#include <metal_stdlib>
using namespace metal;

vertex float4 vertexShader(uint vertexID [[vertex_id]]) {
    // Full-screen triangle
    float2 positions[3] = {
        float2(-1, -1),
        float2( 3, -1),
        float2(-1,  3)
    };
    
    return float4(positions[vertexID], 0, 1);
}
"""

let defaultFragmentShader = """
#include <metal_stdlib>
using namespace metal;

struct ShaderUniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float colorIntensity;
    float waveFrequency;
};

fragment float4 fragmentShader(float4 position [[position]],
                              constant ShaderUniforms &uniforms [[buffer(0)]]) {
    float2 uv = position.xy / uniforms.resolution;
    float2 mouse = uniforms.mouse;
    float time = uniforms.time;
    
    // Center the coordinates
    uv = uv * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    // Animated gradient
    float3 color = 0.5 + 0.5 * cos(time + uv.xyx + float3(0, 2, 4));
    color *= uniforms.colorIntensity;
    
    // Distance from center
    float dist = length(uv);
    
    // Radial waves
    float wave = sin(dist * uniforms.waveFrequency - time * 4.0) * 0.5 + 0.5;
    color += wave * 0.2;
    
    // Vignette
    color *= 1.0 - smoothstep(0.5, 1.5, dist);
    
    return float4(color, 1.0);
}
"""