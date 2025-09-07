import SwiftUI
import MetalKit
import Metal
import UniformTypeIdentifiers

@main
struct ShaderPlaygroundApp: App {
    var body: some Scene {
        WindowGroup("Claude's Shader Playground") {
            AppShellView()
                .frame(minWidth: 1000, minHeight: 700)
        }
    }
}

struct ContentView: View {
    @StateObject private var renderer = MetalShaderRenderer()
    @State private var shaderCode = defaultShader
    
    let communicationDir = "Resources/communication"
    let shaderStateFile = "Resources/communication/current_shader.metal"
    let commandFile = "Resources/communication/commands.json"
    let statusFile = "Resources/communication/status.json"
    let errorsFile = "Resources/communication/compilation_errors.json"
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: Code Editor
            VStack {
                Text("Shader Code")
                    .font(.headline)
                    .padding()
                
                TextEditor(text: $shaderCode)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: shaderCode) { _, newCode in
                        renderer.updateShader(newCode)
                    }
                
                Button("Compile & Update") {
                    renderer.updateShader(shaderCode)
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Right: Metal Preview
            VStack {
                Text("Live Preview")
                    .font(.headline)
                    .padding()
                
                MetalView(renderer: renderer)
                    .aspectRatio(1.0, contentMode: .fit)
                    .padding()
                
                HStack {
                    Button("Export Frame") {
                        renderer.saveScreenshot()
                    }
                    
                    Button("Export Sequence") {
                        renderer.exportFrameSequence(description: "animation_sequence")
                    }
                    
                    Text("FPS: \(Int(renderer.fps))")
                        .font(.system(.body, design: .monospaced))
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            setupCommunication()
            startMonitoringCommands()
        }
    }
    
    // MARK: - Communication Functions
    private func setupCommunication() {
        // Create communication directory
        try? FileManager.default.createDirectory(atPath: communicationDir, withIntermediateDirectories: true)
        
        // Initialize shader state file
        try? shaderCode.write(toFile: shaderStateFile, atomically: true, encoding: .utf8)
        
        // Initialize status file
        let status = ["status": "ready", "timestamp": Date().timeIntervalSince1970] as [String: Any]
        if let statusData = try? JSONSerialization.data(withJSONObject: status) {
            try? statusData.write(to: URL(fileURLWithPath: statusFile))
        }
    }
    
    private func startMonitoringCommands() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            checkForCommands()
        }
    }
    
    private func checkForCommands() {
        guard FileManager.default.fileExists(atPath: commandFile) else { return }
        
        do {
            let commandData = try Data(contentsOf: URL(fileURLWithPath: commandFile))
            let command = try JSONSerialization.jsonObject(with: commandData) as? [String: Any]
            
            if let action = command?["action"] as? String {
                switch action {
                case "set_shader":
                    if let newCode = command?["shader_code"] as? String {
                        DispatchQueue.main.async {
                            self.shaderCode = newCode
                            self.renderer.updateShader(newCode)
                        }
                    }
                case "export_frame":
                    let description = command?["description"] as? String ?? "mcp_export"
                    let time = command?["time"] as? Float
                    renderer.exportFrame(description: description, time: time)
                    
                case "export_sequence":
                    let description = command?["description"] as? String ?? "mcp_sequence"
                    let duration = command?["duration"] as? Float ?? 5.0
                    let fps = command?["fps"] as? Int ?? 30
                    renderer.exportFrameSequence(description: description, duration: duration, fps: fps)
                    
                default:
                    break
                }
                
                // Update status
                updateStatus(action: action, success: true)
                
                // Remove command file
                try? FileManager.default.removeItem(atPath: commandFile)
            }
        } catch {
            updateStatus(action: "unknown", success: false, error: error.localizedDescription)
            try? FileManager.default.removeItem(atPath: commandFile)
        }
    }
    
    private func updateStatus(action: String, success: Bool, error: String? = nil) {
        let status = [
            "last_action": action,
            "success": success,
            "timestamp": Date().timeIntervalSince1970,
            "error": error as Any
        ] as [String: Any]
        
        if let statusData = try? JSONSerialization.data(withJSONObject: status) {
            try? statusData.write(to: URL(fileURLWithPath: statusFile))
        }
        
        // Also update shader state file
        try? shaderCode.write(toFile: shaderStateFile, atomically: true, encoding: .utf8)
    }
}

// MARK: - Metal Renderer
class MetalShaderRenderer: ObservableObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    @Published var fps: Double = 0
    private var pipelineState: MTLRenderPipelineState?
    private var startTime = CACurrentMediaTime()
    
    // Uniform override support (from Resources/communication/uniforms.json)
    private let uniformsFile = "Resources/communication/uniforms.json"
    private var overrideTime: Float?
    private var overrideResolution: SIMD2<Float>?
    private var overrideMouse: SIMD2<Float>?
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported")
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Compile default shader
        updateShader(defaultShader)
        
        // Start polling for uniform overrides
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.loadUniformOverrides()
        }
    }
    
    func updateShader(_ source: String) {
        do {
            let library = try device.makeLibrary(source: source, options: nil)
            guard let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
                print("Could not find fragmentShader function")
                saveCompilationErrors(["Could not find fragmentShader function in shader code"], warnings: [])
                return
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = createVertexFunction()
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("✅ Shader compiled successfully")
            saveCompilationErrors([], warnings: []) // Clear errors on successful compile
            
        } catch {
            print("❌ Shader compilation failed: \(error)")
            let errorMessage = parseMetalError(error.localizedDescription)
            saveCompilationErrors([errorMessage], warnings: [])
        }
    }
    
    private func parseMetalError(_ errorString: String) -> String {
        // Parse Metal compiler errors to extract useful information
        if errorString.contains("program_source") {
            let lines = errorString.components(separatedBy: .newlines)
            for line in lines {
                if line.contains(":") && (line.contains("error:") || line.contains("warning:")) {
                    return line.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return errorString
    }
    
    private func saveCompilationErrors(_ errors: [String], warnings: [String]) {
        let errorsData = [
            "errors": errors.map { error in
                [
                    "message": error,
                    "line": extractLineNumber(from: error) ?? 0,
                    "suggestion": generateSuggestion(for: error)
                ]
            },
            "warnings": warnings.map { warning in
                [
                    "message": warning,
                    "line": extractLineNumber(from: warning) ?? 0
                ]
            },
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        let errorsFile = "Resources/communication/compilation_errors.json"
        if let errorsJsonData = try? JSONSerialization.data(withJSONObject: errorsData, options: .prettyPrinted) {
            try? errorsJsonData.write(to: URL(fileURLWithPath: errorsFile))
        }
    }
    
    private func extractLineNumber(from error: String) -> Int? {
        // Extract line number from Metal error messages
        let pattern = ":(\\d+):"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: error.utf16.count)
        
        if let match = regex?.firstMatch(in: error, options: [], range: range) {
            let lineRange = Range(match.range(at: 1), in: error)
            if let lineRange = lineRange {
                return Int(String(error[lineRange]))
            }
        }
        return nil
    }
    
    private func generateSuggestion(for error: String) -> String {
        let errorLower = error.lowercased()
        
        if errorLower.contains("undeclared identifier") {
            return "Check variable and function names for typos. Make sure all variables are declared."
        } else if errorLower.contains("expected") {
            return "Check syntax - missing semicolons, brackets, or parentheses."
        } else if errorLower.contains("use of undeclared type") {
            return "Make sure all Metal types are spelled correctly (float, float2, float3, float4, etc.)."
        } else if errorLower.contains("fragmentshader") {
            return "Make sure your fragment function is named 'fragmentShader' and has the correct signature."
        }
        return "Review Metal shading language documentation for correct syntax."
    }
    
    // Load uniform overrides from file if present
    private func loadUniformOverrides() {
        guard FileManager.default.fileExists(atPath: uniformsFile) else { return }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: uniformsFile))
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let uniforms = obj?["uniforms"] as? [String: Any]
            
            if let t = uniforms?["time"] as? NSNumber {
                overrideTime = t.floatValue
            } else if uniforms?.keys.contains("time") == true {
                // Explicitly allow clearing the override by setting null
                overrideTime = nil
            }
            
            if let res = uniforms?["resolution"] as? [NSNumber], res.count >= 2 {
                overrideResolution = SIMD2<Float>(res[0].floatValue, res[1].floatValue)
            } else if uniforms?.keys.contains("resolution") == true {
                overrideResolution = nil
            }
            
            if let m = uniforms?["mouse"] as? [NSNumber], m.count >= 2 {
                overrideMouse = SIMD2<Float>(m[0].floatValue, m[1].floatValue)
            } else if uniforms?.keys.contains("mouse") == true {
                overrideMouse = nil
            }
        } catch {
            // Ignore malformed uniforms file
        }
    }
    
    private func createVertexFunction() -> MTLFunction? {
        let vertexSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        vertex float4 vertexShader(uint vertexID [[vertex_id]]) {
            float2 positions[4] = {
                float2(-1, -1),
                float2( 1, -1),
                float2(-1,  1),
                float2( 1,  1)
            };
            return float4(positions[vertexID], 0.0, 1.0);
        }
        """
        
        do {
            let library = try device.makeLibrary(source: vertexSource, options: nil)
            return library.makeFunction(name: "vertexShader")
        } catch {
            print("Failed to create vertex function: \(error)")
            return nil
        }
    }
    
    func render(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        encoder.setRenderPipelineState(pipelineState)
        
        // Pass time, resolution, and optional mouse to shader (with overrides)
        var time = overrideTime ?? Float(CACurrentMediaTime() - startTime)
        var resolution = overrideResolution ?? SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        var mouse = overrideMouse ?? SIMD2<Float>(0.0, 0.0)
        
        encoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        encoder.setFragmentBytes(&resolution, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        encoder.setFragmentBytes(&mouse, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        // Add completion handler BEFORE commit
        commandBuffer.addCompletedHandler { _ in
            DispatchQueue.main.async {
                self.fps = 60.0 // Simplified for now
            }
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func saveScreenshot() {
        exportFrame(description: "manual_screenshot")
    }
    
    func exportFrame(description: String, time: Float? = nil) {
        guard let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("❌ Cannot export - no valid pipeline state")
            return
        }
        
        let width = 1024
        let height = 1024
        
        // Create export texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .renderTarget]
        
        guard let exportTexture = device.makeTexture(descriptor: textureDescriptor) else {
            print("❌ Failed to create export texture")
            return
        }
        
        // Create render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = exportTexture
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        encoder.setRenderPipelineState(pipelineState)
        
        // Set shader uniforms (respect overrides if provided)
        var exportTime = time ?? Float(CACurrentMediaTime() - startTime)
        if let t = overrideTime, time == nil { exportTime = t }
        var resolution = SIMD2<Float>(Float(width), Float(height))
        if let r = overrideResolution { resolution = r }
        var mouse = SIMD2<Float>(0.5, 0.5) // Default center for export
        if let m = overrideMouse { mouse = m }
        
        encoder.setFragmentBytes(&exportTime, length: MemoryLayout<Float>.size, index: 0)
        encoder.setFragmentBytes(&resolution, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        encoder.setFragmentBytes(&mouse, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        // Save to file
        commandBuffer.addCompletedHandler { _ in
            self.saveTextureToFile(exportTexture, description: description, time: exportTime)
        }
        
        commandBuffer.commit()
    }
    
    func exportFrameSequence(description: String, duration: Float = 5.0, fps: Int = 30) {
        let frameCount = Int(duration * Float(fps))
        let timeStep = duration / Float(frameCount)
        
        print("🎬 Exporting \(frameCount) frames over \(duration)s...")
        
        for frame in 0..<frameCount {
            let time = Float(frame) * timeStep
            let frameDesc = "\(description)_frame_\(String(format: "%04d", frame))_t\(String(format: "%.3f", time))"
            
            // Small delay to prevent overwhelming the GPU
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(frame) * 0.1) {
                self.exportFrame(description: frameDesc, time: time)
            }
        }
    }
    
    private func saveTextureToFile(_ texture: MTLTexture, description: String, time: Float) {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        let imageByteCount = bytesPerRow * height
        
        let imageBytes = UnsafeMutableRawPointer.allocate(byteCount: imageByteCount, alignment: 1)
        defer { imageBytes.deallocate() }
        
        texture.getBytes(imageBytes, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        
        // Create CGImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        guard let dataProvider = CGDataProvider(dataInfo: nil, data: imageBytes, size: imageByteCount, releaseData: { _, _, _ in }),
              let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo,
                                  provider: dataProvider, decode: nil, shouldInterpolate: false,
                                  intent: .defaultIntent) else {
            print("❌ Failed to create CGImage")
            return
        }
        
        // Save to file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "\(timestamp)_\(description).png"
        let resourcesDir = "Resources/exports"
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)
        
        let url = URL(fileURLWithPath: "\(resourcesDir)/\(filename)")
        
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            print("❌ Failed to create image destination")
            return
        }
        
        // Add metadata
        let metadata: [String: Any] = [
            "time": time,
            "description": description,
            "resolution": "\(width)x\(height)",
            "export_timestamp": timestamp
        ]
        
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            print("✅ Frame exported: \(filename) (t=\(String(format: "%.3f", time)))")
        } else {
            print("❌ Failed to save frame: \(filename)")
        }
    }
}

// MARK: - Metal View
struct MetalView: NSViewRepresentable {
    let renderer: MetalShaderRenderer
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.colorPixelFormat = .bgra8Unorm
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Updates handled in delegate
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        let renderer: MetalShaderRenderer
        
        init(_ renderer: MetalShaderRenderer) {
            self.renderer = renderer
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize if needed
        }
        
        func draw(in view: MTKView) {
            renderer.render(in: view)
        }
    }
}

// MARK: - Default Shader
let defaultShader = """
#include <metal_stdlib>
using namespace metal;

fragment float4 fragmentShader(float4 position [[position]],
                              constant float &time [[buffer(0)]],
                              constant float2 &resolution [[buffer(1)]]) {
    float2 uv = position.xy / resolution;
    
    // Simple animated gradient
    float3 color = 0.5 + 0.5 * cos(time + uv.xyx + float3(0, 2, 4));
    
    return float4(color, 1.0);
}
"""
