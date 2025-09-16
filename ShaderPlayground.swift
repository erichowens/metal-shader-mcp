import SwiftUI
import MetalKit
import Metal
import UniformTypeIdentifiers
import CryptoKit
import AppKit
import QuartzCore

@main
struct ShaderPlaygroundApp: App {
    @StateObject var appState = AppState()

    var body: some Scene {
        WindowGroup("Claude's Shader Playground") {
            AppShellView(initialTab: Self.initialTabFromArgs())
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 700)
        }
    }

    private static func initialTabFromArgs() -> AppTab {
        let args = CommandLine.arguments
        func map(_ s: String) -> AppTab? {
            switch s.lowercased() {
            case "repl": return .repl
            case "library": return .library
            case "projects": return .projects
            case "tools", "mcp", "mcp-tools": return .tools
            case "history", "sessions": return .history
            default: return nil
            }
        }
        if let i = args.firstIndex(of: "--tab"), i+1 < args.count, let t = map(args[i+1]) { return t }
        if let i = args.firstIndex(of: "-t"), i+1 < args.count, let t = map(args[i+1]) { return t }
        return .repl
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var renderer = MetalShaderRenderer()
    @StateObject private var session = SessionRecorder()
@State private var shaderCode = defaultShader
    @State private var shaderMeta = ShaderMetadata.from(code: defaultShader, path: nil)
    
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
                    .onChange(of: shaderCode) { newCode in
                        renderer.updateShader(newCode)
                        shaderMeta = ShaderMetadata.from(code: newCode, path: shaderStateFile)
                        writeCurrentShaderMeta()
                    }
                
HStack(spacing: 12) {
                    Button("Compile & Update") {
renderer.updateShader(shaderCode)
                        shaderMeta = ShaderMetadata.from(code: shaderCode, path: shaderStateFile)
                        writeCurrentShaderMeta()
                    }
                    Button("Save As…") {
                        saveAsShaderDialog()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Right: Metal Preview
VStack {
                Text("Live Preview")
                    .font(.headline)
                    .padding(.top)
                // Shader name and description (from docstring)
                VStack(alignment: .leading, spacing: 4) {
                    Text(shaderMeta.name.isEmpty ? "Untitled Shader" : shaderMeta.name)
                        .font(.title3).bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !shaderMeta.description.isEmpty {
                        Text(shaderMeta.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
                
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
        // Ensure metadata is initialized
        shaderMeta = ShaderMetadata.from(code: shaderCode, path: shaderStateFile)
        writeCurrentShaderMeta()
        // Create communication directory
        try? FileManager.default.createDirectory(atPath: communicationDir, withIntermediateDirectories: true)
        
        // Initialize shader state file
MCP.shared.writeText(shaderCode, to: shaderStateFile)
        
        // Initialize status file
        let status = ["status": "ready", "timestamp": Date().timeIntervalSince1970] as [String: Any]
MCP.shared.writeJSON(status, to: statusFile)
    }
    
private func startMonitoringCommands() {
        // Ensure communication dir exists
        try? FileManager.default.createDirectory(atPath: communicationDir, withIntermediateDirectories: true)
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
                        let desc = command?["description"] as? String
                        let noSnapshot = (command?["no_snapshot"] as? Bool) ?? false
                        DispatchQueue.main.async {
                            self.shaderCode = newCode
                            self.renderer.updateShader(newCode)
                            if !noSnapshot {
                                self.session.recordSnapshot(code: newCode, renderer: self.renderer, label: desc)
                            }
                        }
                    }
case "get_shader_meta":
                    // Write current shader meta (already maintained)
                    self.writeCurrentShaderMeta()

                case "set_shader_with_meta":
                    let newCode = command?["shader_code"] as? String
                    let name = command?["name"] as? String
                    let desc = command?["description"] as? String
                    let path = command?["path"] as? String
                    let save = (command?["save"] as? Bool) ?? false
                    let noSnapshot = (command?["no_snapshot"] as? Bool) ?? false
                    DispatchQueue.main.async {
                        if let newCode = newCode {
                            self.shaderCode = newCode
                            self.renderer.updateShader(newCode)
                        }
                        // Update metadata
                        var meta = ShaderMetadata.from(code: self.shaderCode, path: self.shaderStateFile)
                        if let name = name { meta.name = name }
                        if let desc = desc { meta.description = desc }
                        if let path = path, !path.isEmpty { meta.path = path }
                        self.shaderMeta = meta
                        self.writeCurrentShaderMeta()
                        // Save to path if requested
                        if save, let p = meta.path, !p.isEmpty {
                            Self.writeTextSafely(self.shaderCode, toPath: p)
                        }
                        if !noSnapshot {
                            self.session.recordSnapshot(code: self.shaderCode, renderer: self.renderer, label: "set_shader_with_meta")
                        }
                    }

                case "list_library_entries":
                    self.writeLibraryIndex()

                case "save_snapshot":
                    let desc = command?["description"] as? String ?? "snapshot"
                    DispatchQueue.main.async {
                        self.session.recordSnapshot(code: self.shaderCode, renderer: self.renderer, label: desc)
                    }
                case "export_frame":
                    let description = command?["description"] as? String ?? "mcp_export"
                    let time = command?["time"] as? Float
                    renderer.exportFrame(description: description, time: time)
                    
                case "set_tab":
                    if let tabName = command?["tab"] as? String {
                        DispatchQueue.main.async {
                            let lower = tabName.lowercased()
                            if lower == "repl" { self.appState.selectedTab = .repl }
                            else if lower == "library" { self.appState.selectedTab = .library }
                            else if lower == "projects" { self.appState.selectedTab = .projects }
                            else if lower == "tools" || lower == "mcp" || lower == "mcp-tools" { self.appState.selectedTab = .tools }
                            else if lower == "history" || lower == "sessions" { self.appState.selectedTab = .history }
                        }
                    }
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
        
MCP.shared.writeJSON(status, to: statusFile)
        
        // Also update shader state file
MCP.shared.writeText(shaderCode, to: shaderStateFile)
    }
}

// MARK: - Shader Metadata
struct ShaderMetadata: Codable {
    var name: String
    var description: String
    var path: String?

    static func from(code: String, path: String?) -> ShaderMetadata {
        // Extract the first block comment /** ... */ as docstring
        // Fallbacks if not present
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        var title = ""
        var desc = ""
        if let startRange = trimmed.range(of: "/**"), let endRange = trimmed.range(of: "*/", range: startRange.upperBound..<trimmed.endIndex) {
            let doc = String(trimmed[startRange.upperBound..<endRange.lowerBound])
            // Split into lines, strip leading * and spaces
            let lines = doc.split(separator: "\n").map { line -> String in
                var s = String(line)
                if s.trimmingCharacters(in: .whitespaces).hasPrefix("*") {
                    s = s.replacingOccurrences(of: "*", with: "", options: [], range: s.range(of: "*"))
                }
                return s.trimmingCharacters(in: .whitespaces)
            }
            // First non-empty line as title, subsequent non-empty lines until blank as description (joined)
            var i = 0
            while i < lines.count && lines[i].isEmpty { i += 1 }
            if i < lines.count { title = lines[i]; i += 1 }
            var descLines: [String] = []
            while i < lines.count {
                let l = lines[i]
                if l.isEmpty { break }
                descLines.append(l)
                i += 1
            }
            desc = descLines.joined(separator: " ")
        }
        if title.isEmpty { title = "Untitled Shader" }
        return ShaderMetadata(name: title, description: desc, path: path)
    }
}

extension ContentView {
    func saveAsShaderDialog() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["metal"]
        panel.canCreateDirectories = true
        panel.title = "Save Shader As"
        // Default directory: ./shaders
        let shadersDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("shaders")
        try? FileManager.default.createDirectory(at: shadersDir, withIntermediateDirectories: true)
        panel.directoryURL = shadersDir
        panel.nameFieldStringValue = (shaderMeta.name.isEmpty ? "Untitled Shader" : shaderMeta.name).replacingOccurrences(of: " ", with: "_").lowercased() + ".metal"
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            Self.writeTextSafely(shaderCode, toPath: path)
            // Update meta path and rewrite meta
            shaderMeta.path = path
            writeCurrentShaderMeta()
        }
    }

    static func writeTextSafely(_ text: String, toPath path: String) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        // If file exists, replace
        if FileManager.default.fileExists(atPath: path) {
            _ = try? FileManager.default.removeItem(atPath: path)
        }
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
    }

    func writeLibraryIndex() {
        let shadersDir = "shaders"
        var entries: [[String: Any]] = []
        if let files = try? FileManager.default.contentsOfDirectory(atPath: shadersDir) {
            for fn in files where fn.hasSuffix(".metal") {
                let full = shadersDir + "/" + fn
                if let code = try? String(contentsOfFile: full) {
                    let meta = ShaderMetadata.from(code: code, path: full)
                    entries.append([
                        "name": meta.name,
                        "description": meta.description,
                        "path": full
                    ])
                }
            }
        }
        let obj: [String: Any] = [
            "entries": entries,
            "count": entries.count,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: communicationDir + "/library_index.json"))
        }
    }
    func writeCurrentShaderMeta() {
        let meta = shaderMeta
        let obj: [String: Any] = [
            "name": meta.name,
            "description": meta.description,
            "path": meta.path ?? "",
            "timestamp": Date().timeIntervalSince1970
        ]
MCP.shared.writeJSON(obj, to: communicationDir + "/library_index.json")
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
            // In CI (or headless), Metal can be unavailable. Avoid crashing the build; provide a stub.
            fatalError("Metal is not supported in this environment")
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
        let resourcesDir = "Resources/screenshots"
        
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
