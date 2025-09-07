import SwiftUI
import MetalKit
import Combine

// MARK: - Metal Rendering View
struct MetalRenderingView: NSViewRepresentable {
    @EnvironmentObject var workspace: WorkspaceManager
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = workspace.renderer.device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 120
        
        context.coordinator.mtkView = mtkView
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.workspace = workspace
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(workspace: workspace)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        weak var workspace: WorkspaceManager?
        weak var mtkView: MTKView?
        
        init(workspace: WorkspaceManager) {
            self.workspace = workspace
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            workspace?.renderer.updateViewportSize(size)
        }
        
        func draw(in view: MTKView) {
            workspace?.renderer.draw(in: view)
        }
    }
}

// MARK: - Metal Code Editor
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
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .medium) // Bolder font
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isRichText = true // Must be true for syntax highlighting
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.importsGraphics = false
        textView.delegate = context.coordinator
        textView.string = text // Set initial text
        
        // Apply theme
        applyTheme(to: textView)
        
        // Syntax highlighting
        context.coordinator.applySyntaxHighlighting(to: textView)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Only update text if not currently editing
        let isFirstResponder = textView.window?.firstResponder == textView
        if !isFirstResponder && textView.string != text {
            textView.string = text
            context.coordinator.applySyntaxHighlighting(to: textView)
        }
        
        // Always ensure text view remains editable
        textView.isEditable = true
        textView.isSelectable = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    private func applyTheme(to textView: NSTextView) {
        switch theme {
        case .professional:
            // ULTRA high contrast theme for maximum readability
            textView.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1) // Darker bg
            textView.textColor = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // Pure white text
            textView.insertionPointColor = NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1)
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 0.8),
                .foregroundColor: NSColor.white
            ]
        case .midnight:
            textView.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
            textView.textColor = NSColor(red: 0.75, green: 0.75, blue: 0.76, alpha: 1)
        case .solarized:
            textView.backgroundColor = NSColor(red: 0, green: 0.17, blue: 0.21, alpha: 1)
            textView.textColor = NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1)
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MetalCodeEditor
        private let highlightingQueue = DispatchQueue(label: "syntax.highlighting", qos: .userInitiated)
        
        init(parent: MetalCodeEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onTextChange()
            
            // Update cursor position
            let selectedRange = textView.selectedRange()
            let textStorage = textView.textStorage!
            let layoutManager = textStorage.layoutManagers.first!
            
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
            
            // Debounced syntax highlighting
            highlightingQueue.async { [weak self] in
                DispatchQueue.main.async {
                    self?.applySyntaxHighlighting(to: textView)
                }
            }
        }
        
        func applySyntaxHighlighting(to textView: NSTextView) {
            let text = textView.string
            guard let textStorage = textView.textStorage else { return }
            
            textStorage.beginEditing()
            
            // Reset to WHITE text (not default/black)
            let fullRange = NSRange(location: 0, length: text.count)
            textStorage.addAttribute(.foregroundColor, value: NSColor.white, range: fullRange)
            
            // Keywords - brighter colors for better contrast
            let keywords = ["float", "float2", "float3", "float4", "int", "uint", "bool",
                           "vertex", "fragment", "kernel", "struct", "constant", "device",
                           "using", "namespace", "return", "if", "else", "for", "while",
                           "#include", "#define", "#pragma"]
            
            for keyword in keywords {
                highlightPattern(keyword, color: NSColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1), in: textStorage) // Very bright blue
            }
            
            // Functions - very bright purple
            let functions = ["sin", "cos", "tan", "pow", "sqrt", "abs", "min", "max",
                           "mix", "clamp", "smoothstep", "length", "normalize", "dot", "cross",
                           "fract", "floor", "ceil", "mod", "step", "reflect", "refract"]
            
            for function in functions {
                highlightPattern(function, color: NSColor(red: 0.9, green: 0.6, blue: 1.0, alpha: 1), in: textStorage) // Very bright purple
            }
            
            // Comments - bright green
            highlightPattern("//.*$", color: NSColor(red: 0.6, green: 1.0, blue: 0.6, alpha: 1), in: textStorage, isRegex: true)
            highlightPattern("/\\*[\\s\\S]*?\\*/", color: NSColor(red: 0.6, green: 1.0, blue: 0.6, alpha: 1), in: textStorage, isRegex: true)
            
            // Numbers - brighter orange
            highlightPattern("\\b\\d+\\.?\\d*f?\\b", color: NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1), in: textStorage, isRegex: true)
            
            // Strings - brighter red
            highlightPattern("\"[^\"]*\"", color: NSColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1), in: textStorage, isRegex: true)
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
                        let beforeIndex = foundRange.location > 0 ? foundRange.location - 1 : 0
                        let afterIndex = foundRange.location + foundRange.length
                        
                        let beforeChar = beforeIndex > 0 ? (text as NSString).character(at: beforeIndex) : 0
                        let afterChar = afterIndex < text.count ? (text as NSString).character(at: afterIndex) : 0
                        
                        let isWordBoundary = !CharacterSet.alphanumerics.contains(UnicodeScalar(beforeChar)!) &&
                                           !CharacterSet.alphanumerics.contains(UnicodeScalar(afterChar)!)
                        
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
            
            textStorage.endEditing()
        }
    }
}

// MARK: - Workspace Manager
class WorkspaceManager: ObservableObject {
    static let shared = WorkspaceManager()
    
    // Shader management
    @Published var currentShader: ShaderDocument?
    @Published var shaderTabs: [ShaderTabModel] = []
    @Published var hasUnsavedChanges = false
    
    // Parameters
    @Published var timeParameter: ShaderParameter
    @Published var resolutionParameter: ShaderParameter
    @Published var mouseParameter: ShaderParameter
    @Published var customParameters: [ShaderParameter] = []
    @Published var presets: [ShaderPreset] = []
    
    // Playback
    @Published var isPlaying = true
    @Published var currentFrame = 0
    
    // Performance
    @Published var fps: Double = 0
    
    // MCP Logs
    @Published var mcpLogs: [MCPLogEntry] = []
    @Published var frameTime: Double = 0
    @Published var gpuTime: Double = 0
    
    // Editor state
    @Published var cursorPosition = (line: 1, column: 1)
    @Published var compilationStatus: CompilationStatus = .ready
    @Published var compilationErrors: [CompilationError] = []
    
    // MCP
    let mcpServer = MCPServer()
    
    // Renderer
    let renderer: MetalRenderer
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize built-in parameters
        timeParameter = ShaderParameter(
            id: UUID(),
            name: "time",
            type: .float,
            value: .float(0),
            range: 0...10,
            isBuiltin: true
        )
        
        resolutionParameter = ShaderParameter(
            id: UUID(),
            name: "resolution",
            type: .float2,
            value: .vector2(1920, 1080),
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
        
        renderer.compileShader(currentTab.content) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.compilationStatus = .success
                    self?.compilationErrors = []
                    self?.addMCPLog(level: "info", message: "Shader compiled successfully")
                case .failure(let errors):
                    self?.compilationStatus = .error
                    self?.compilationErrors = errors
                    self?.addMCPLog(level: "error", message: "Shader compilation failed with \(errors.count) errors")
                }
            }
        }
    }
    
    func addShaderTab() {
        let newTab = ShaderTabModel(
            id: UUID(),
            title: "New Shader",
            content: ""
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
    
    func scheduleCompilation() {
        // Debounced compilation - compile after 500ms of no changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.compileCurrentShader()
        }
    }
    
    func resetAnimation() {
        currentFrame = 0
        timeParameter.value = .float(0)
        renderer.resetTime()
    }
    
    func togglePlayback() {
        isPlaying.toggle()
        renderer.setPaused(!isPlaying)
    }
    
    func captureFrame() {
        renderer.captureCurrentFrame { image in
            // Save to desktop
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let url = desktop.appendingPathComponent("MetalStudio_\(Date().timeIntervalSince1970).png")
            
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
            }
        }
    }
    
    func resetParameters() {
        timeParameter.value = .float(0)
        mouseParameter.value = .vector2(0.5, 0.5)
        for i in customParameters.indices {
            customParameters[i].resetToDefault()
        }
        renderer.updateUniforms(getAllParameterValues())
    }
    
    func updateMousePosition(_ location: CGPoint, in size: CGSize) {
        let normalized = CGPoint(
            x: location.x / size.width,
            y: 1.0 - (location.y / size.height)
        )
        mouseParameter.value = .vector2(Float(normalized.x), Float(normalized.y))
        renderer.updateMousePosition(normalized)
    }
    
    func extractParametersFromShader() {
        guard let currentTab = shaderTabs.first else { return }
        
        let extractor = ShaderParameterExtractor()
        let extracted = extractor.extract(from: currentTab.content)
        
        for param in extracted {
            if !customParameters.contains(where: { $0.name == param.name }) {
                customParameters.append(param)
            }
        }
    }
    
    func addCustomParameter() {
        let newParam = ShaderParameter(
            id: UUID(),
            name: "custom\(customParameters.count + 1)",
            type: .float,
            value: .float(0.5),
            range: 0...1,
            isBuiltin: false
        )
        customParameters.append(newParam)
    }
    
    func updateParameter(_ id: UUID, value: Float) {
        if timeParameter.id == id {
            timeParameter.value = .float(value)
        } else if let index = customParameters.firstIndex(where: { $0.id == id }) {
            customParameters[index].value = .float(value)
        }
        renderer.updateUniforms(getAllParameterValues())
    }
    
    func updateParameter(_ id: UUID, x: Float) {
        if mouseParameter.id == id {
            if case .vector2(_, let y) = mouseParameter.value {
                mouseParameter.value = .vector2(x, y)
            }
        } else if let index = customParameters.firstIndex(where: { $0.id == id }) {
            if case .vector2(_, let y) = customParameters[index].value {
                customParameters[index].value = .vector2(x, y)
            }
        }
        renderer.updateUniforms(getAllParameterValues())
    }
    
    func updateParameter(_ id: UUID, y: Float) {
        if mouseParameter.id == id {
            if case .vector2(let x, _) = mouseParameter.value {
                mouseParameter.value = .vector2(x, y)
            }
        } else if let index = customParameters.firstIndex(where: { $0.id == id }) {
            if case .vector2(let x, _) = customParameters[index].value {
                customParameters[index].value = .vector2(x, y)
            }
        }
        renderer.updateUniforms(getAllParameterValues())
    }
    
    func updateParameter(_ id: UUID, color: Color) {
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
            let nsColor = NSColor(color)
            customParameters[index].value = .vector3(
                Float(nsColor.redComponent),
                Float(nsColor.greenComponent),
                Float(nsColor.blueComponent)
            )
        }
        renderer.updateUniforms(getAllParameterValues())
    }
    
    func updateParameter(_ id: UUID, intValue: Int) {
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
            customParameters[index].value = .int(intValue)
        }
        renderer.updateUniforms(getAllParameterValues())
    }
    
    func updateParameter(_ id: UUID, boolValue: Bool) {
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
            customParameters[index].value = .bool(boolValue)
        }
        renderer.updateUniforms(getAllParameterValues())
    }
    
    func savePreset() {
        let preset = ShaderPreset(
            id: UUID(),
            name: "Preset \(presets.count + 1)",
            parameters: getAllParameterValues(),
            timestamp: Date()
        )
        presets.append(preset)
    }
    
    func loadPreset(_ preset: ShaderPreset) {
        // Apply preset values
        for (key, value) in preset.parameters {
            if key == "time" {
                timeParameter.value = value
            } else if key == "mouse" {
                mouseParameter.value = value
            } else if let param = customParameters.first(where: { $0.name == key }) {
                param.value = value
            }
        }
        renderer.updateUniforms(preset.parameters)
    }
    
    private func getAllParameterValues() -> [String: ShaderParameter.Value] {
        var values: [String: ShaderParameter.Value] = [:]
        values[timeParameter.name] = timeParameter.value
        values[resolutionParameter.name] = resolutionParameter.value
        values[mouseParameter.name] = mouseParameter.value
        
        for param in customParameters {
            values[param.name] = param.value
        }
        
        return values
    }
}

// MARK: - Supporting Types
struct ShaderTabModel: Identifiable {
    let id: UUID
    var title: String
    var content: String
}

struct ShaderDocument: Identifiable {
    let id: UUID
    var name: String
    var path: URL?
    var content: String
    var lastModified: Date
}

class ShaderParameter: ObservableObject, Identifiable {
    let id: UUID
    let name: String
    let type: ParameterType
    @Published var value: Value
    let range: ClosedRange<Float>
    let isBuiltin: Bool
    private let defaultValue: Value
    
    enum ParameterType {
        case float, float2, float3, int, bool
    }
    
    enum Value {
        case float(Float)
        case vector2(Float, Float)
        case vector3(Float, Float, Float)
        case int(Int)
        case bool(Bool)
    }
    
    init(id: UUID, name: String, type: ParameterType, value: Value, range: ClosedRange<Float>, isBuiltin: Bool) {
        self.id = id
        self.name = name
        self.type = type
        self.value = value
        self.defaultValue = value
        self.range = range
        self.isBuiltin = isBuiltin
    }
    
    func resetToDefault() {
        value = defaultValue
    }
    
    var formattedValue: String {
        switch value {
        case .float(let f):
            return String(format: "%.3f", f)
        case .vector2(let x, let y):
            return String(format: "(%.2f, %.2f)", x, y)
        case .vector3(let r, let g, let b):
            return String(format: "(%.2f, %.2f, %.2f)", r, g, b)
        case .int(let i):
            return "\(i)"
        case .bool(let b):
            return b ? "true" : "false"
        }
    }
    
    var floatValue: Float {
        if case .float(let f) = value { return f }
        return 0
    }
    
    var vectorValue: (x: Float, y: Float) {
        if case .vector2(let x, let y) = value { return (x, y) }
        return (0, 0)
    }
    
    var colorValue: Color {
        if case .vector3(let r, let g, let b) = value {
            return Color(red: Double(r), green: Double(g), blue: Double(b))
        }
        return .white
    }
    
    var intValue: Int {
        if case .int(let i) = value { return i }
        return 0
    }
    
    var boolValue: Bool {
        if case .bool(let b) = value { return b }
        return false
    }
}

struct ShaderPreset: Identifiable {
    let id: UUID
    var name: String
    var parameters: [String: ShaderParameter.Value]
    var timestamp: Date
}

enum CompilationStatus {
    case ready, compiling, success, error
}

struct CompilationError {
    let line: Int
    let column: Int
    let message: String
    let severity: Severity
    
    enum Severity {
        case error, warning
    }
}

// MARK: - Compilation Result
enum CompilationResult {
    case success
    case failure([CompilationError])
}

// MARK: - Metal Renderer (continued in separate file due to size)
class MetalRenderer {
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    
    private var viewportSize = CGSize(width: 1920, height: 1080)
    private var startTime = Date()
    private var currentTime: Float = 0
    private var isPaused = false
    
    private var mousePosition = CGPoint.zero
    private var uniforms = Uniforms()
    
    struct Uniforms {
        var time: Float = 0
        var resolution: SIMD2<Float> = SIMD2<Float>(1920, 1080)
        var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
        var custom1: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0)
        var custom2: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0)
        var custom3: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0)
    }
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            fatalError("Metal is not supported on this device")
        }
        
        self.device = device
        self.commandQueue = queue
        
        setupBuffers()
        compileDefaultShaders()
    }
    
    private func setupBuffers() {
        // Full-screen quad vertices as float4 (position.xy, texCoord.xy)
        let vertices: [SIMD4<Float>] = [
            SIMD4<Float>(-1, -1, 0, 1),  // bottom left
            SIMD4<Float>( 1, -1, 1, 1),  // bottom right
            SIMD4<Float>(-1,  1, 0, 0),  // top left
            SIMD4<Float>( 1,  1, 1, 0)   // top right
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                        length: vertices.count * MemoryLayout<SIMD4<Float>>.size,
                                        options: [])
        
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size,
                                         options: [])
    }
    
    private func compileDefaultShaders() {
        do {
            let library = try device.makeLibrary(source: fullMetalShaderSource, options: nil)
            
            guard let vertexFunction = library.makeFunction(name: "vertexShader"),
                  let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
                print("Error: Could not find shader functions")
                return
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Error compiling default shaders: \(error)")
        }
    }
    
    func compileShader(_ source: String, completion: @escaping (CompilationResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Check if source already has a vertex shader
            let hasVertexShader = source.contains("vertex ") && source.contains("vertexShader")
            
            // Combine with vertex shader if needed
            let fullSource = hasVertexShader ? source : vertexShaderSource + "\n\n" + source
            
            do {
                let library = try self.device.makeLibrary(source: fullSource, options: nil)
                
                let vertexFunction = library.makeFunction(name: "vertexShader")
                let fragmentFunction = library.makeFunction(name: "fragmentShader")
                
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = vertexFunction
                pipelineDescriptor.fragmentFunction = fragmentFunction
                pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                
                let newPipeline = try self.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                
                DispatchQueue.main.async {
                    self.pipelineState = newPipeline
                    completion(.success)
                }
            } catch let error as NSError {
                let errors = self.parseCompilationErrors(from: error.localizedDescription)
                completion(.failure(errors))
            }
        }
    }
    
    private func parseCompilationErrors(from errorString: String) -> [CompilationError] {
        var errors: [CompilationError] = []
        
        let lines = errorString.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("error:") || line.contains("warning:") {
                let isError = line.contains("error:")
                
                // Extract line number and message
                if let match = line.range(of: #"(\d+):(\d+):\s*(error|warning):\s*(.+)"#,
                                         options: .regularExpression) {
                    let components = line[match].components(separatedBy: ":")
                    if components.count >= 4 {
                        let lineNum = Int(components[0]) ?? 0
                        let colNum = Int(components[1]) ?? 0
                        let message = components[3...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
                        
                        errors.append(CompilationError(
                            line: lineNum,
                            column: colNum,
                            message: message,
                            severity: isError ? .error : .warning
                        ))
                    }
                }
            }
        }
        
        if errors.isEmpty {
            errors.append(CompilationError(
                line: 0,
                column: 0,
                message: errorString,
                severity: .error
            ))
        }
        
        return errors
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        // Set clear color to dark gray so we can see if it's rendering
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        
        // If no pipeline, try to create a simple one
        if pipelineState == nil {
            print("No pipeline state - compiling default shaders...")
            compileDefaultShaders()
            
            // Still render the clear color
            if let commandBuffer = commandQueue.makeCommandBuffer() {
                let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
                encoder?.endEncoding()
                commandBuffer.present(drawable)
                commandBuffer.commit()
            }
            return
        }
        
        guard let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        // Update time
        if !isPaused {
            currentTime = Float(Date().timeIntervalSince(startTime))
        }
        
        // Update uniforms
        uniforms.time = currentTime
        uniforms.resolution = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
        
        // Copy uniforms to buffer
        uniformBuffer?.contents().copyMemory(from: &uniforms,
                                            byteCount: MemoryLayout<Uniforms>.size)
        
        // Render
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Update performance metrics
        updatePerformanceMetrics()
    }
    
    func updateViewportSize(_ size: CGSize) {
        viewportSize = size
    }
    
    func updateMousePosition(_ position: CGPoint) {
        mousePosition = position
        uniforms.mouse = SIMD2<Float>(Float(position.x), Float(position.y))
    }
    
    func setPaused(_ paused: Bool) {
        isPaused = paused
    }
    
    func resetTime() {
        startTime = Date()
        currentTime = 0
    }
    
    func updateUniforms(_ parameters: [String: ShaderParameter.Value]) {
        // Update uniform buffer with parameter values
        for (name, value) in parameters {
            switch value {
            case .float(let f):
                if name == "time" {
                    uniforms.time = f
                }
            case .vector2(let x, let y):
                if name == "resolution" {
                    uniforms.resolution = SIMD2<Float>(x, y)
                } else if name == "mouse" {
                    uniforms.mouse = SIMD2<Float>(x, y)
                }
            case .vector3(let r, let g, let b):
                // Map to custom uniforms
                uniforms.custom1 = SIMD4<Float>(r, g, b, 1.0)
            default:
                break
            }
        }
    }
    
    func captureCurrentFrame(completion: @escaping (NSImage) -> Void) {
        // Implement frame capture
        // This would render to an offscreen texture and read it back
    }
    
    private func updatePerformanceMetrics() {
        // Track FPS and frame time
        WorkspaceManager.shared.fps = 60 // Placeholder - would calculate actual FPS
        WorkspaceManager.shared.frameTime = 16.67
    }
}

// MARK: - Shader Parameter Extractor
class ShaderParameterExtractor {
    func extract(from source: String) -> [ShaderParameter] {
        var parameters: [ShaderParameter] = []
        
        // Parse shader source for uniform declarations
        let pattern = #"constant\s+(\w+)\s+[&*]?(\w+)\s*\[\[buffer\((\d+)\)\]\]"#
        
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
            
            for match in matches {
                if let typeRange = Range(match.range(at: 1), in: source),
                   let nameRange = Range(match.range(at: 2), in: source) {
                    
                    let typeString = String(source[typeRange])
                    let name = String(source[nameRange])
                    
                    // Skip built-in parameters
                    if name == "time" || name == "resolution" || name == "mouse" {
                        continue
                    }
                    
                    // Determine parameter type and create parameter
                    let param = createParameter(name: name, type: typeString)
                    parameters.append(param)
                }
            }
        }
        
        return parameters
    }
    
    private func createParameter(name: String, type: String) -> ShaderParameter {
        let paramType: ShaderParameter.ParameterType
        let defaultValue: ShaderParameter.Value
        let range: ClosedRange<Float>
        
        switch type {
        case "float":
            paramType = .float
            defaultValue = .float(0.5)
            range = 0...1
        case "float2":
            paramType = .float2
            defaultValue = .vector2(0.5, 0.5)
            range = -1...1
        case "float3":
            paramType = .float3
            defaultValue = .vector3(1, 1, 1)
            range = 0...1
        case "int":
            paramType = .int
            defaultValue = .int(1)
            range = 0...10
        case "bool":
            paramType = .bool
            defaultValue = .bool(false)
            range = 0...1
        default:
            paramType = .float
            defaultValue = .float(0.5)
            range = 0...1
        }
        
        return ShaderParameter(
            id: UUID(),
            name: name,
            type: paramType,
            value: defaultValue,
            range: range,
            isBuiltin: false
        )
    }
}

// MARK: - Shader Sources
let vertexShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float4 custom1;
    float4 custom2;
    float4 custom3;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              constant float4 *vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = vertices[vertexID];
    out.texCoord = vertices[vertexID].zw;
    return out;
}
"""

let defaultFragmentShader = """
// Fragment shader - VertexOut is already defined in vertex shader
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 mouse = uniforms.mouse;
    float time = uniforms.time;
    
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