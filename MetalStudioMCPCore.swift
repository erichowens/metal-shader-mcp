import SwiftUI
import Metal
import MetalKit
import Combine
import AppKit

// MARK: - Workspace Manager
class WorkspaceManager: ObservableObject {
    static let shared = WorkspaceManager()
    
    @Published var shaderTabs: [ShaderTabModel] = []
    @Published var selectedTabIndex = 0
    @Published var hasUnsavedChanges = false
    @Published var compilationStatus: CompilationStatus = .idle
    @Published var compilationErrors: [CompilationError] = []
    @Published var cursorPosition: (line: Int, column: Int) = (1, 1)
    @Published var mcpLogs: [MCPLogEntry] = []
    @Published var renderer: MetalRenderer!
    @Published var timeParameter: ShaderParameter!
    @Published var resolutionParameter: ShaderParameter!
    @Published var mouseParameter: ShaderParameter!
    @Published var mcpServer = MCPServer()
    @Published var isPlaying = true
    @Published var fps: Double = 60.0
    @Published var frameTime: Double = 16.67
    @Published var customParameters: [ShaderParameter] = []
    @Published var shaderPresets: [ShaderPreset] = []
    @Published var shaderLibrary: [ShaderLibraryItem] = []
    @Published var mcpFunctions: [MCPFunction] = []
    
    // Video export settings
    @Published var videoDuration: Double = 5.0  // seconds
    @Published var videoFPS: Int = 60
    @Published var isExportingVideo = false
    @Published var exportProgress: Double = 0.0
    
    // Resolution settings
    @Published var renderWidth: Float = 1920
    @Published var renderHeight: Float = 1080
    
    // Computed property alias for components that reference 'presets'
    var presets: [ShaderPreset] {
        get { shaderPresets }
        set { shaderPresets = newValue }
    }
    
    var mcpConfigJSON: String {
        """
        {
          "mcpServers": {
            "metal-shader-studio": {
              "command": "node",
              "args": ["\(FileManager.default.homeDirectoryForCurrentUser.path)/coding/metal-shader-mcp/dist/index.js"],
              "env": {
                "NODE_ENV": "production"
              }
            }
          }
        }
        """
    }
    
    init() {
        // Initialize parameters
        timeParameter = ShaderParameter(
            id: UUID(),
            name: "time",
            type: .float,
            value: .float(0),
            range: 0...100,
            isBuiltin: true
        )
        
        resolutionParameter = ShaderParameter(
            id: UUID(),
            name: "resolution",
            type: .float2,
            value: .vector2(renderWidth, renderHeight),
            range: 0...4096,
            isBuiltin: true
        )
        
        mouseParameter = ShaderParameter(
            id: UUID(),
            name: "mouse",
            type: .float2,
            value: .vector2(0.5, 0.5),
            range: 0...1,
            isBuiltin: true
        )
        
        // Initialize renderer
        renderer = MetalRenderer()
        
        // Setup default shader
        setupDefaultShader()
        
        // Initialize shader library
        initializeShaderLibrary()
        
        // Initialize MCP functions
        initializeMCPFunctions()
    }
    
    private func setupDefaultShader() {
        let defaultShader = ShaderTabModel(
            id: UUID(),
            title: "Fragment",
            content: defaultFragmentShader
        )
        shaderTabs.append(defaultShader)
        
        compileCurrentShader()
    }
    
    func createNewShader() {
        let newShader = ShaderTabModel(
            id: UUID(),
            title: "Untitled",
            content: defaultFragmentShader
        )
        shaderTabs.append(newShader)
    }
    
    func compileCurrentShader() {
        compilationStatus = .compiling
        
        guard let currentTab = shaderTabs.first else { return }
        
        // Auto-extract parameters before compilation
        extractParametersFromShader()
        
        renderer.compileShader(currentTab.content) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.compilationStatus = .success
                    self?.compilationErrors = []
                    self?.addMCPLog(level: "info", message: "Shader compiled successfully")
                case .failure(let error):
                    self?.compilationStatus = .error
                    self?.compilationErrors = error.errors
                    self?.addMCPLog(level: "error", message: "Shader compilation failed with \(error.errors.count) errors")
                }
            }
        }
    }
    
    func addShaderTab() {
        let defaultShaderContent = """
        // Metal Shader
        fragment float4 fragmentShader(
            VertexOut in [[stage_in]],
            constant float &time [[buffer(0)]],
            constant float2 &resolution [[buffer(1)]],
            constant float2 &mouse [[buffer(2)]]
        ) {
            float2 uv = (in.position.xy - 0.5 * resolution) / min(resolution.x, resolution.y);
            
            // Simple gradient effect
            float3 col = 0.5 + 0.5 * cos(time + uv.xyx + float3(0, 2, 4));
            
            return float4(col, 1.0);
        }
        """
        
        let newTab = ShaderTabModel(
            id: UUID(),
            title: "New Shader",
            content: defaultShaderContent
        )
        shaderTabs.append(newTab)
    }
    
    func markAsModified() {
        hasUnsavedChanges = true
    }
    
    func saveCurrentShader() {
        guard let currentTab = shaderTabs.first else { return }
        
        // Save to file
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(currentTab.title).metal"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try currentTab.content.write(to: url, atomically: true, encoding: .utf8)
                hasUnsavedChanges = false
                addMCPLog(level: "info", message: "Saved shader to \(url.lastPathComponent)")
            } catch {
                addMCPLog(level: "error", message: "Failed to save: \(error)")
            }
        }
    }
    
    private var compilationTimer: Timer?
    
    func scheduleCompilation() {
        compilationTimer?.invalidate()
        compilationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.compileCurrentShader()
        }
    }
    
    func addMCPLog(level: String, message: String, source: String? = nil) {
        let entry = MCPLogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            source: source
        )
        mcpLogs.append(entry)
    }
    
    var currentShader: ShaderTabModel? {
        shaderTabs.first
    }
    
    func resetParameters() {
        // Reset parameters to defaults
        timeParameter.value = .float(0)
        mouseParameter.value = .vector2(0.5, 0.5)
        // Reset custom parameters to their default values
        for i in 0..<customParameters.count {
            // Keep the type but reset value to a sensible default
            switch customParameters[i].type {
            case .float:
                customParameters[i].value = .float(0.5)
            case .float2:
                customParameters[i].value = .vector2(0.5, 0.5)
            case .float3:
                customParameters[i].value = .vector3(0.5, 0.5, 0.5)
            case .float4:
                customParameters[i].value = .vector4(1.0, 0.0, 0.0, 1.0)
            case .int:
                customParameters[i].value = .int(1)
            case .bool:
                customParameters[i].value = .bool(false)
            case .color:
                customParameters[i].value = .color(1.0, 1.0, 1.0, 1.0)
            }
        }
    }
    
    func restartShader() {
        // Reset time to 0 and restart playback
        timeParameter.value = .float(0)
        isPlaying = true
        addMCPLog(level: "info", message: "Shader restarted")
    }
    
    func updateMousePosition(_ location: CGPoint, in size: CGSize) {
        // Normalize mouse position to 0-1 range
        let normalizedX = Float(location.x / size.width)
        let normalizedY = Float(1.0 - location.y / size.height) // Flip Y coordinate
        mouseParameter.value = .vector2(normalizedX, normalizedY)
    }
    
    func togglePlayback() {
        isPlaying.toggle()
    }
    
    func captureFrame() {
        exportImage()
    }
    
    func exportImage() {
        // Capture current frame as PNG
        guard let texture = renderer.currentTexture else {
            addMCPLog(level: "error", message: "No texture available to export")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "shader-output.png"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            // Get texture dimensions
            let width = texture.width
            let height = texture.height
            let bytesPerRow = width * 4 // BGRA = 4 bytes per pixel
            
            // Create buffer to hold texture data
            let dataSize = height * bytesPerRow
            var pixelData = [UInt8](repeating: 0, count: dataSize)
            
            // Copy texture data to buffer
            let region = MTLRegionMake2D(0, 0, width, height)
            texture.getBytes(&pixelData, 
                           bytesPerRow: bytesPerRow,
                           from: region,
                           mipmapLevel: 0)
            
            // Create CGImage from pixel data
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            
            guard let dataProvider = CGDataProvider(data: NSData(bytes: pixelData, length: dataSize)),
                  let cgImage = CGImage(width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bitsPerPixel: 32,
                                       bytesPerRow: bytesPerRow,
                                       space: colorSpace,
                                       bitmapInfo: bitmapInfo,
                                       provider: dataProvider,
                                       decode: nil,
                                       shouldInterpolate: true,
                                       intent: .defaultIntent) else {
                addMCPLog(level: "error", message: "Failed to create image from texture data")
                return
            }
            
            // Create NSImage and save as PNG
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
            
            if let tiffData = nsImage.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                do {
                    try pngData.write(to: url)
                    addMCPLog(level: "info", message: "Image exported to \(url.lastPathComponent)")
                } catch {
                    addMCPLog(level: "error", message: "Failed to save image: \(error.localizedDescription)")
                }
            } else {
                addMCPLog(level: "error", message: "Failed to convert image to PNG format")
            }
        }
    }
    
    func saveShader() {
        guard let currentTab = currentShader else { return }
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = currentTab.title.hasSuffix(".metal") ? currentTab.title : "\(currentTab.title).metal"
        panel.allowedContentTypes = [.plainText]
        panel.allowsOtherFileTypes = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try currentTab.content.write(to: url, atomically: true, encoding: .utf8)
                    self.hasUnsavedChanges = false
                    self.addMCPLog(level: "info", message: "Shader saved to \(url.lastPathComponent)")
                } catch {
                    self.addMCPLog(level: "error", message: "Failed to save shader: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func exportPNG() {
        exportImage()
    }
    
    func exportVideo() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "shader-animation.mp4"
        panel.allowedContentTypes = [.mpeg4Movie]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.startVideoExport(to: url)
            }
        }
    }
    
    private func startVideoExport(to url: URL) {
        isExportingVideo = true
        exportProgress = 0.0
        
        // Calculate total frames
        let totalFrames = Int(videoDuration * Double(videoFPS))
        let frameDuration = 1.0 / Double(videoFPS)
        
        addMCPLog(level: "info", message: "Starting video export: \(totalFrames) frames at \(videoFPS) FPS")
        
        // Store original time
        let originalTime = timeParameter.floatValue
        let originalIsPlaying = isPlaying
        isPlaying = false
        
        // Reset time for export
        timeParameter.value = .float(0)
        
        // TODO: Implement actual frame capture and video encoding
        // For now, just simulate the export process
        DispatchQueue.global(qos: .userInitiated).async {
            for frame in 0..<totalFrames {
                let currentTime = Float(frame) * Float(frameDuration)
                
                DispatchQueue.main.sync {
                    self.timeParameter.value = .float(currentTime)
                    self.exportProgress = Double(frame) / Double(totalFrames)
                }
                
                // Simulate frame capture delay
                Thread.sleep(forTimeInterval: 0.01)
                
                if !self.isExportingVideo {
                    break  // Export cancelled
                }
            }
            
            DispatchQueue.main.async {
                // Restore original state
                self.timeParameter.value = .float(originalTime)
                self.isPlaying = originalIsPlaying
                self.isExportingVideo = false
                self.exportProgress = 0.0
                self.addMCPLog(level: "info", message: "Video export completed")
            }
        }
    }
    
    func cancelVideoExport() {
        isExportingVideo = false
        addMCPLog(level: "info", message: "Video export cancelled")
    }
    
    func exportCode() {
        guard let currentTab = currentShader else { return }
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(currentTab.title).metal"
        panel.allowedContentTypes = [.plainText]
        panel.allowsOtherFileTypes = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    // Export with full Metal boilerplate if needed
                    let hasVertexShader = currentTab.content.contains("vertex ") || currentTab.content.contains("vertexShader")
                    let fullCode = hasVertexShader ? currentTab.content : 
                                   vertexShaderSource + "\n\n" + currentTab.content
                    try fullCode.write(to: url, atomically: true, encoding: .utf8)
                    self.addMCPLog(level: "info", message: "Shader code exported to \(url.lastPathComponent)")
                } catch {
                    self.addMCPLog(level: "error", message: "Failed to export code: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func startMCPServer() {
        mcpServer.start()
    }
    
    func stopMCPServer() {
        mcpServer.stop()
    }
    
    func testMCPConnection() {
        mcpServer.testConnection()
    }
    
    func exportMCPConfig() {
        // Export MCP configuration
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "mcp-config.json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            let config = """
            {
              "mcpServers": {
                "metal-shader-studio": {
                  "command": "node",
                  "args": ["\(FileManager.default.homeDirectoryForCurrentUser.path)/coding/metal-shader-mcp/dist/index.js"],
                  "env": {
                    "NODE_ENV": "production"
                  }
                }
              }
            }
            """
            
            do {
                try config.write(to: url, atomically: true, encoding: .utf8)
                addMCPLog(level: "info", message: "Exported MCP config to \(url.lastPathComponent)")
            } catch {
                addMCPLog(level: "error", message: "Failed to export config: \(error)")
            }
        }
    }
    
    func clearMCPLogs() {
        mcpLogs.removeAll()
        addMCPLog(level: "info", message: "Logs cleared")
    }
    
    func updateParameter(_ id: UUID, value: Float) {
        // Update custom parameters
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
            customParameters[index].floatValue = value
        }
        // Update builtin parameters
        if timeParameter.id == id {
            timeParameter.floatValue = value
        } else if mouseParameter.id == id {
            mouseParameter.floatValue = value
        } else if resolutionParameter.id == id {
            resolutionParameter.floatValue = value
        }
    }
    
    // Overload for vector2 components
    func updateParameter(_ id: UUID, value: Float, isXComponent: Bool) {
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
            if case .vector2(let x, let y) = customParameters[index].value {
                if isXComponent {
                    customParameters[index].value = .vector2(value, y)
                } else {
                    customParameters[index].value = .vector2(x, value)
                }
            }
        }
    }
    
    func updateParameter(_ id: UUID, value: Float, isYComponent: Bool) {
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
            if case .vector2(let x, let y) = customParameters[index].value {
                if isYComponent {
                    customParameters[index].value = .vector2(x, value)
                } else {
                    customParameters[index].value = .vector2(value, y)
                }
            }
        }
    }
    
    func updateParameter(_ id: UUID, color: Color) {
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
            let nsColor = NSColor(color)
            customParameters[index].value = .color(
                Float(nsColor.redComponent),
                Float(nsColor.greenComponent),
                Float(nsColor.blueComponent),
                Float(nsColor.alphaComponent)
            )
        }
    }
    
    func updateParameter(_ id: UUID, intValue: Int) {
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
            customParameters[index].value = .int(intValue)
        }
    }
    
    func updateParameter(_ id: UUID, boolValue: Bool) {
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
            customParameters[index].value = .bool(boolValue)
        }
    }
    
    func savePreset() {
        guard let current = shaderTabs.first else { return }
        let preset = ShaderPreset(
            name: current.title,
            code: current.content,
            description: "Custom shader preset",
            parameters: customParameters
        )
        shaderPresets.append(preset)
        addMCPLog(level: "info", message: "Saved preset: \(preset.name)")
    }
    
    func loadPreset(_ preset: ShaderPreset) {
        // Load the preset's code into the current tab
        if shaderTabs.isEmpty {
            addShaderTab()
        }
        if let currentTab = shaderTabs.first {
            currentTab.content = preset.code
            currentTab.title = preset.name
            markAsModified()
        }
        
        // Load the preset's parameters
        customParameters = preset.parameters
        
        addMCPLog(level: "info", message: "Loaded preset: \(preset.name)")
    }
    
    func addCustomParameter() {
        let newParam = ShaderParameter(
            name: "custom\(customParameters.count + 1)",
            type: .float,
            value: .float(0.5),
            range: 0...1
        )
        customParameters.append(newParam)
    }
    
    func extractParametersFromShader() {
        guard let currentTab = shaderTabs.first else { return }
        
        // Advanced parameter extraction from Metal shader code
        let shaderCode = currentTab.content
        
        // Keep existing custom parameters but update if found in shader
        var foundParams: [String: ShaderParameter] = [:]
        
        // Pattern for Metal constant parameters: constant type& name [[buffer(index)]]
        // Also look for simple constant declarations
        let patterns = [
            // constant float& turbulence [[buffer(3)]]
            "constant\\s+(float|float2|float3|float4|int|bool)\\s*&\\s*(\\w+)\\s*\\[\\[buffer\\((\\d+)\\)\\]\\]",
            // constant float turbulence = 0.5;
            "constant\\s+(float|float2|float3|float4|int|bool)\\s+(\\w+)\\s*=\\s*([^;]+);",
            // For legacy GLSL-style: uniform float paramName;
            "uniform\\s+(float|vec2|vec3|vec4|int|bool)\\s+(\\w+)\\s*(?:=\\s*([^;]+))?;"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: shaderCode, options: [], 
                                           range: NSRange(location: 0, length: shaderCode.count))
                
                for match in matches {
                    // Extract type
                    let typeRange = match.range(at: 1)
                    let nameRange = match.range(at: 2)
                    
                    if typeRange.location != NSNotFound && nameRange.location != NSNotFound {
                        let typeStr = (shaderCode as NSString).substring(with: typeRange)
                        let nameStr = (shaderCode as NSString).substring(with: nameRange)
                        
                        // Skip built-in parameters
                        if ["iTime", "iResolution", "iMouse", "time", "resolution", "mouse"].contains(nameStr) {
                            continue
                        }
                        
                        // Determine parameter type
                        let paramType: ParameterType
                        let defaultValue: ShaderValue
                        
                        switch typeStr {
                        case "float":
                            paramType = .float
                            defaultValue = .float(0.5)
                        case "float2", "vec2":
                            paramType = .float2
                            defaultValue = .vector2(0.5, 0.5)
                        case "float3", "vec3":
                            paramType = .float3
                            defaultValue = .vector3(0.5, 0.5, 0.5)
                        case "float4", "vec4":
                            paramType = .float4
                            defaultValue = .vector4(1.0, 0.0, 0.0, 1.0)
                        case "int":
                            paramType = .int
                            defaultValue = .int(1)
                        case "bool":
                            paramType = .bool
                            defaultValue = .bool(false)
                        default:
                            continue
                        }
                        
                        // Try to extract default value if present
                        var actualValue = defaultValue
                        if match.numberOfRanges > 3 {
                            let valueRange = match.range(at: 3)
                            if valueRange.location != NSNotFound {
                                let valueStr = (shaderCode as NSString).substring(with: valueRange).trimmingCharacters(in: .whitespaces)
                                actualValue = parseShaderValue(valueStr, type: paramType) ?? defaultValue
                            }
                        }
                        
                        // Check if parameter already exists and preserve its value
                        if let existingParam = customParameters.first(where: { $0.name == nameStr }) {
                            foundParams[nameStr] = ShaderParameter(
                                name: nameStr,
                                type: paramType,
                                value: existingParam.value,  // Keep existing value
                                range: existingParam.range   // Keep existing range
                            )
                        } else {
                            // Create reasonable ranges based on common shader parameter patterns
                            let range: ClosedRange<Float> = determineParameterRange(name: nameStr, type: paramType)
                            
                            foundParams[nameStr] = ShaderParameter(
                                name: nameStr,
                                type: paramType,
                                value: actualValue,
                                range: range
                            )
                        }
                    }
                }
            } catch {
                print("Regex error: \(error)")
            }
        }
        
        // Update custom parameters
        customParameters = Array(foundParams.values).sorted { $0.name < $1.name }
        
        addMCPLog(level: "info", message: "Auto-extracted \(customParameters.count) parameters from shader")
    }
    
    private func parseShaderValue(_ str: String, type: ParameterType) -> ShaderValue? {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        
        switch type {
        case .float:
            if let val = Float(trimmed.replacingOccurrences(of: "f", with: "")) {
                return .float(val)
            }
        case .float2:
            // Parse float2(x, y) or vec2(x, y)
            let pattern = "(?:float2|vec2)\\s*\\(\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.count)) {
                let x = (trimmed as NSString).substring(with: match.range(at: 1))
                let y = (trimmed as NSString).substring(with: match.range(at: 2))
                if let xVal = Float(x.replacingOccurrences(of: "f", with: "")),
                   let yVal = Float(y.replacingOccurrences(of: "f", with: "")) {
                    return .vector2(xVal, yVal)
                }
            }
        case .int:
            if let val = Int(trimmed) {
                return .int(val)
            }
        case .bool:
            return .bool(trimmed == "true" || trimmed == "1")
        default:
            break
        }
        return nil
    }
    
    private func determineParameterRange(name: String, type: ParameterType) -> ClosedRange<Float> {
        let nameLower = name.lowercased()
        
        // Smart range detection based on parameter name
        if nameLower.contains("scale") || nameLower.contains("zoom") {
            return 0.1...10.0
        } else if nameLower.contains("speed") || nameLower.contains("rate") {
            return 0.0...5.0
        } else if nameLower.contains("intensity") || nameLower.contains("strength") || nameLower.contains("amount") {
            return 0.0...1.0
        } else if nameLower.contains("frequency") {
            return 0.1...20.0
        } else if nameLower.contains("rotation") || nameLower.contains("angle") {
            return 0.0...6.28318  // 0 to 2π
        } else if nameLower.contains("count") || nameLower.contains("iterations") {
            return 1.0...100.0
        } else if nameLower.contains("threshold") {
            return 0.0...1.0
        } else if nameLower.contains("size") || nameLower.contains("radius") {
            return 0.01...2.0
        } else if type == .bool {
            return 0.0...1.0
        } else if type == .int {
            return 0.0...10.0
        } else {
            return 0.0...1.0  // Default range
        }
    }
    
    func loadShaderFromLibrary(_ shader: ShaderLibraryItem) {
        let newTab = ShaderTabModel(
            id: UUID(),
            title: shader.name,
            content: shader.code
        )
        
        if shaderTabs.isEmpty {
            shaderTabs.append(newTab)
        } else {
            shaderTabs[0] = newTab
        }
        
        hasUnsavedChanges = true
        
        // Reset time when loading new shader
        timeParameter.value = .float(0)
        
        // Compile and auto-extract parameters
        compileCurrentShader()
        
        addMCPLog(level: "info", message: "Loaded shader: \(shader.name)")
    }
    
    func updateResolution(width: Float, height: Float) {
        renderWidth = width
        renderHeight = height
        resolutionParameter.value = .vector2(width, height)
        
        // Notify renderer about resolution change
        if let texture = renderer.currentTexture {
            // Resolution will be applied on next frame
            addMCPLog(level: "info", message: "Resolution updated to \(Int(width))×\(Int(height))")
        }
    }
    
    private func initializeShaderLibrary() {
        // Initialize with built-in shaders
        shaderLibrary = [
            ShaderLibraryItem(
                name: "Kaleidoscope",
                category: "Geometric",
                code: fixedKaleidoscopeShaderCode,
                description: "A mesmerizing kaleidoscope effect with rotating patterns",
                hasMouseInteraction: true,
                estimatedFPS: 60,
                complexity: "Medium"
            ),
            ShaderLibraryItem(
                name: "Plasma",
                category: "Plasma",
                code: plasmaShaderCode,
                description: "Classic plasma effect with smooth color transitions",
                hasMouseInteraction: false,
                estimatedFPS: 60,
                complexity: "Low"
            ),
            ShaderLibraryItem(
                name: "Fractal Explorer",
                category: "Fractals",
                code: fractalShaderCode,
                description: "Interactive Mandelbrot fractal explorer",
                hasMouseInteraction: true,
                estimatedFPS: 45,
                complexity: "High"
            ),
            ShaderLibraryItem(
                name: "Wave Pattern",
                category: "Basic",
                code: waveShaderCode,
                description: "Simple wave interference pattern",
                hasMouseInteraction: false,
                estimatedFPS: 60,
                complexity: "Low"
            )
        ]
    }
    
    private func initializeMCPFunctions() {
        // Initialize MCP function definitions
        mcpFunctions = [
            MCPFunction(
                name: "compile_shader",
                description: "Compile a Metal shader and report any errors",
                icon: "hammer",
                parameters: [
                    MCPFunctionParameter(
                        name: "code",
                        type: "string",
                        description: "The Metal shader code to compile",
                        required: true
                    )
                ],
                example: "compile_shader(code: \"fragment float4 fragmentShader(...) { ... }\")",
                requiresAuth: false
            ),
            MCPFunction(
                name: "update_parameter",
                description: "Update a shader parameter value",
                icon: "slider.horizontal.3",
                parameters: [
                    MCPFunctionParameter(
                        name: "name",
                        type: "string",
                        description: "The parameter name",
                        required: true
                    ),
                    MCPFunctionParameter(
                        name: "value",
                        type: "float | float2 | float3 | float4",
                        description: "The new value",
                        required: true
                    )
                ],
                example: "update_parameter(name: \"time\", value: 3.14)",
                requiresAuth: false
            ),
            MCPFunction(
                name: "load_preset",
                description: "Load a shader preset from the library",
                icon: "doc.text",
                parameters: [
                    MCPFunctionParameter(
                        name: "preset_name",
                        type: "string",
                        description: "Name of the preset to load",
                        required: true
                    )
                ],
                example: "load_preset(preset_name: \"Kaleidoscope\")",
                requiresAuth: false
            ),
            MCPFunction(
                name: "export_image",
                description: "Export the current frame as an image",
                icon: "square.and.arrow.up",
                parameters: [
                    MCPFunctionParameter(
                        name: "path",
                        type: "string",
                        description: "Path where to save the image",
                        required: true
                    ),
                    MCPFunctionParameter(
                        name: "format",
                        type: "string",
                        description: "Image format (png, jpg)",
                        required: false
                    )
                ],
                example: "export_image(path: \"/tmp/shader.png\", format: \"png\")",
                requiresAuth: true
            )
        ]
    }
}

// MARK: - Custom Text View for Better Control
class CustomTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTextView()
    }
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    private func setupTextView() {
        self.isEditable = true
        self.isSelectable = true
        self.isRichText = false
        self.importsGraphics = false
        self.isAutomaticQuoteSubstitutionEnabled = false
        self.isAutomaticTextReplacementEnabled = false
        self.isAutomaticSpellingCorrectionEnabled = false
        self.isContinuousSpellCheckingEnabled = false
        self.isGrammarCheckingEnabled = false
        self.allowsUndo = true
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        self.window?.makeFirstResponder(self)
        return result
    }
    
    override func keyDown(with event: NSEvent) {
        // Handle special keys
        if event.modifierFlags.contains(.command) {
            // Let command shortcuts pass through
            super.keyDown(with: event)
        } else {
            // Normal text input
            super.keyDown(with: event)
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Allow standard text editing shortcuts
        if event.modifierFlags.contains(.command) {
            let key = event.charactersIgnoringModifiers
            if key == "a" || key == "c" || key == "v" || key == "x" || key == "z" {
                return super.performKeyEquivalent(with: event)
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Fixed Metal Code Editor
struct MetalCodeEditor: NSViewRepresentable {
    @Binding var text: String
    let language: CodeLanguage
    let theme: EditorTheme
    let onTextChange: () -> Void
    
    enum CodeLanguage {
        case metal, glsl, hlsl
    }
    
    enum EditorTheme {
        case professional, midnight, solarized
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        
        let contentSize = scrollView.contentSize
        
        let textView = CustomTextView(frame: CGRect(origin: .zero, size: contentSize), textContainer: nil)
        textView.minSize = CGSize(width: 0, height: 0)
        textView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = CGSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // Setup text view properties
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        textView.string = text
        textView.delegate = context.coordinator
        
        scrollView.documentView = textView
        
        // Apply theme
        applyTheme(to: textView)
        
        // Apply initial syntax highlighting AND make first responder
        DispatchQueue.main.async {
            context.coordinator.applySyntaxHighlighting(to: textView)
            // Make the text view first responder to ensure it can receive keyboard input
            if let window = textView.window {
                window.makeFirstResponder(textView)
            }
        }
        
        // Store reference for later use
        context.coordinator.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Only update if text has changed externally (not from user typing)
        if textView.string != text && !context.coordinator.isUpdatingText {
            context.coordinator.isUpdatingText = true
            
            // Save selection
            let selectedRange = textView.selectedRange()
            
            // Update text
            textView.string = text
            
            // Restore selection if valid
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
            
            // Apply syntax highlighting
            context.coordinator.applySyntaxHighlighting(to: textView)
            
            context.coordinator.isUpdatingText = false
            
            // Ensure text view remains first responder
            DispatchQueue.main.async {
                if let window = textView.window {
                    window.makeFirstResponder(textView)
                }
            }
        }
    }
    
    private func applyTheme(to textView: NSTextView) {
        // CRITICAL: Enable background drawing
        textView.drawsBackground = true
        
        switch theme {
        case .professional:
            textView.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
            textView.textColor = NSColor.white
            textView.insertionPointColor = NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1)
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.5),
                .foregroundColor: NSColor.white
            ]
        case .midnight:
            textView.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
            textView.textColor = NSColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1)
            textView.insertionPointColor = NSColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1)
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor(red: 0.2, green: 0.3, blue: 0.6, alpha: 0.5),
                .foregroundColor: NSColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1)
            ]
        case .solarized:
            textView.backgroundColor = NSColor(red: 0, green: 0.17, blue: 0.21, alpha: 1)
            textView.textColor = NSColor(red: 0.58, green: 0.63, blue: 0.63, alpha: 1)
            textView.insertionPointColor = NSColor(red: 0.42, green: 0.44, blue: 0.77, alpha: 1)
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor(red: 0.07, green: 0.22, blue: 0.27, alpha: 0.8),
                .foregroundColor: NSColor(red: 0.58, green: 0.63, blue: 0.63, alpha: 1)
            ]
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MetalCodeEditor
        weak var textView: NSTextView?
        var isUpdatingText = false
        
        init(_ parent: MetalCodeEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard !isUpdatingText,
                  let textView = notification.object as? NSTextView else { return }
            
            // Update the binding
            self.parent.text = textView.string
            self.parent.onTextChange()
            
            // Update cursor position
            let selectedRange = textView.selectedRange()
            var lineNumber = 1
            var columnNumber = 1
            
            let text = textView.string as NSString
            var charIndex = 0
            
            while charIndex < selectedRange.location {
                if text.character(at: charIndex) == 10 { // newline
                    lineNumber += 1
                    columnNumber = 1
                } else {
                    columnNumber += 1
                }
                charIndex += 1
            }
            
            WorkspaceManager.shared.cursorPosition = (lineNumber, columnNumber)
            
            // Apply syntax highlighting
            self.applySyntaxHighlighting(to: textView)
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Allow all text editing commands
            return false
        }
        
        func applySyntaxHighlighting(to textView: NSTextView) {
            let text = textView.string
            guard let textStorage = textView.textStorage else { return }
            
            // Save selection
            let selectedRanges = textView.selectedRanges
            
            textStorage.beginEditing()
            
            // Reset to theme's default text color (not always white!)
            let fullRange = NSRange(location: 0, length: text.count)
            let defaultColor: NSColor
            switch parent.theme {
            case .professional:
                defaultColor = NSColor.white
            case .midnight:
                defaultColor = NSColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1)
            case .solarized:
                defaultColor = NSColor(red: 0.58, green: 0.63, blue: 0.63, alpha: 1)
            }
            textStorage.removeAttribute(.foregroundColor, range: fullRange)
            textStorage.addAttribute(.foregroundColor, value: defaultColor, range: fullRange)
            
            // Keywords - bright blue
            let keywords = ["float", "float2", "float3", "float4", "int", "uint", "bool",
                           "vertex", "fragment", "kernel", "struct", "constant", "device",
                           "using", "namespace", "return", "if", "else", "for", "while",
                           "#include", "#define", "#pragma"]
            
            for keyword in keywords {
                highlightPattern(keyword, color: NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1), in: textStorage)
            }
            
            // Functions - bright purple
            let functions = ["sin", "cos", "tan", "pow", "sqrt", "abs", "min", "max",
                           "mix", "clamp", "smoothstep", "length", "normalize", "dot", "cross",
                           "fract", "floor", "ceil", "mod", "step", "reflect", "refract"]
            
            for function in functions {
                highlightPattern(function, color: NSColor(red: 0.8, green: 0.5, blue: 1.0, alpha: 1), in: textStorage)
            }
            
            // Comments - bright green
            highlightPattern("//.*$", color: NSColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1), in: textStorage, isRegex: true)
            
            // Numbers - orange
            highlightPattern("\\b\\d+\\.?\\d*f?\\b", color: NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1), in: textStorage, isRegex: true)
            
            textStorage.endEditing()
            
            // Restore selection
            textView.selectedRanges = selectedRanges
        }
        
        private func highlightPattern(_ pattern: String, color: NSColor, in textStorage: NSTextStorage, isRegex: Bool = false) {
            let text = textStorage.string
            
            if isRegex {
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
                    let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
                    
                    for match in matches {
                        textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
                    }
                } catch {
                    print("Regex error: \(error)")
                }
            } else {
                var searchRange = NSRange(location: 0, length: text.count)
                
                while searchRange.location < text.count {
                    let foundRange = (text as NSString).range(of: pattern, options: [.caseInsensitive], range: searchRange)
                    
                    if foundRange.location != NSNotFound {
                        // Check word boundaries
                        var isWordBoundary = true
                        
                        if foundRange.location > 0 {
                            let beforeChar = (text as NSString).character(at: foundRange.location - 1)
                            if CharacterSet.alphanumerics.contains(UnicodeScalar(beforeChar)!) {
                                isWordBoundary = false
                            }
                        }
                        
                        if isWordBoundary && foundRange.location + foundRange.length < text.count {
                            let afterChar = (text as NSString).character(at: foundRange.location + foundRange.length)
                            if CharacterSet.alphanumerics.contains(UnicodeScalar(afterChar)!) {
                                isWordBoundary = false
                            }
                        }
                        
                        if isWordBoundary {
                            textStorage.addAttribute(.foregroundColor, value: color, range: foundRange)
                        }
                        
                        searchRange.location = foundRange.location + foundRange.length
                        searchRange.length = text.count - searchRange.location
                    } else {
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Metal Renderer
class MetalRenderer: NSObject, ObservableObject {
    @Published var device: MTLDevice!
    @Published var commandQueue: MTLCommandQueue!
    @Published var pipelineState: MTLRenderPipelineState?
    @Published var vertexBuffer: MTLBuffer!
    @Published var currentTexture: MTLTexture?
    @Published var gpuTime: Double = 0.0  // GPU rendering time in milliseconds
    
    private var shaderLibrary: MTLLibrary?
    
    override init() {
        super.init()
        setupMetal()
    }
    
    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported")
        }
        
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        // Create vertex buffer
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 1.0,
             1.0, -1.0, 0.0, 1.0,
            -1.0,  1.0, 0.0, 1.0,
             1.0,  1.0, 0.0, 1.0,
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
    }
    
    private func detectVertexShader(in source: String) -> Bool {
        // Check for various vertex shader signatures
        return source.contains("vertex VertexOut") ||
               source.contains("vertex float4") ||
               source.contains("[[attribute(") ||
               source.contains("vertexShader(") ||
               source.contains("vertex_main(") ||
               (source.contains("vertex ") && source.contains("[[stage_in]]"))
    }
    
    private func detectFragmentShader(in source: String) -> Bool {
        // Check for various fragment shader signatures
        return source.contains("fragment float4") ||
               source.contains("fragment half4") ||
               source.contains("fragmentShader(") ||
               source.contains("fragment_main(") ||
               source.contains("[[stage_in]]") ||
               source.contains("fragment ") ||
               source.contains("frag_main(")
    }
    
    func compileShader(_ source: String, completion: @escaping (Result<Void, ShaderCompilationError>) -> Void) {
        // Better shader format detection
        let hasVertexShader = detectVertexShader(in: source)
        let hasFragmentShader = detectFragmentShader(in: source)
        
        // Determine what needs to be added
        var fullSource = source
        
        if !hasVertexShader && !hasFragmentShader {
            // It's just a fragment shader code, add full boilerplate
            fullSource = vertexShaderSource + "\n\n" + source
        } else if !hasVertexShader && hasFragmentShader {
            // Has fragment shader but missing vertex shader
            fullSource = vertexShaderSource + "\n\n" + source
        } else if hasVertexShader && !hasFragmentShader {
            // Has vertex shader but missing fragment shader - unusual case
            // Leave as is, will fail with clear error
            fullSource = source
        }
        // If both are present, use source as-is
        
        // Create compile options to capture diagnostics
        let options = MTLCompileOptions()
        options.fastMathEnabled = true
        
        do {
            shaderLibrary = try device.makeLibrary(source: fullSource, options: options)
            
            guard let vertexFunction = shaderLibrary?.makeFunction(name: "vertexShader"),
                  let fragmentFunction = shaderLibrary?.makeFunction(name: "fragmentShader") else {
                let error = CompilationError(
                    line: 0, 
                    column: 0, 
                    message: "Failed to find vertex or fragment shader functions", 
                    type: .error
                )
                completion(.failure(ShaderCompilationError(errors: [error])))
                return
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            completion(.success(()))
            
        } catch {
            var errors: [CompilationError] = []
            
            // Parse the error message for line numbers and details
            let errorMessage = error.localizedDescription
            let lines = errorMessage.components(separatedBy: "\n")
            
            for line in lines where !line.isEmpty {
                // Try to extract line number from error message
                // Metal compiler errors often have format: "program_source:line:column: error: message"
                if let range = line.range(of: ":"), 
                   let lineNumRange = line.range(of: ":", options: [], range: range.upperBound..<line.endIndex) {
                    let lineInfo = line[range.upperBound..<lineNumRange.lowerBound]
                    if let lineNum = Int(lineInfo) {
                        let message = String(line[lineNumRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                        errors.append(CompilationError(
                            line: lineNum,
                            column: 0,
                            message: message.isEmpty ? line : message,
                            type: .error
                        ))
                        continue
                    }
                }
                
                // Fallback: add the whole line as an error
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append(CompilationError(
                        line: 0,
                        column: 0,
                        message: line,
                        type: .error
                    ))
                }
            }
            
            // If no specific errors were parsed, add the whole error
            if errors.isEmpty {
                errors.append(CompilationError(
                    line: 0,
                    column: 0,
                    message: errorMessage,
                    type: .error
                ))
            }
            
            completion(.failure(ShaderCompilationError(errors: errors)))
        }
    }
}

// MARK: - Shader Templates
let vertexShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    
    float2 texCoords[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };
    
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    
    return out;
}
"""

let defaultFragmentShader = """
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              constant float &time [[buffer(0)]],
                              constant float2 &resolution [[buffer(1)]],
                              constant float2 &mouse [[buffer(2)]]) {
    float2 uv = in.texCoord;
    
    // Animated gradient with mouse interaction
    float3 color = 0.5 + 0.5 * cos(time + uv.xyx + float3(0, 2, 4));
    
    // Add mouse influence
    float dist = length(uv - mouse);
    color *= 1.0 - smoothstep(0.0, 0.5, dist);
    
    // Radial waves
    float wave = sin(dist * 20.0 - time * 4.0) * 0.5 + 0.5;
    color += wave * 0.2;
    
    return float4(color, 1.0);
}
"""

let fullMetalShaderSource = vertexShaderSource + "\n\n" + defaultFragmentShader