import SwiftUI
import MetalKit
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - Main App
@main
struct MetalStudioProfessionalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var workspace = WorkspaceManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workspace)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Shader") {
                    workspace.createNewShader()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(before: .toolbar) {
                Button("Compile") {
                    workspace.compileCurrentShader()
                }
                .keyboardShortcut("b", modifiers: .command)
                
                Divider()
                
                Button("Reset Parameters") {
                    workspace.resetParameters()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var editorWidth: CGFloat = 400
    @State private var inspectorWidth: CGFloat = 320
    @State private var showInspector = true
    @State private var showConsole = false
    @State private var consoleHeight: CGFloat = 200
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color(red: 0.11, green: 0.11, blue: 0.12)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Toolbar
                    ToolbarView(
                        showInspector: $showInspector,
                        showConsole: $showConsole
                    )
                    .frame(height: 38)
                    
                    Divider()
                        .background(Color.black.opacity(0.5))
                    
                    // Main content area
                    HSplitView {
                        // Code Editor
                        ShaderEditorView()
                            .frame(
                                minWidth: 300,
                                idealWidth: editorWidth,
                                maxWidth: 600
                            )
                        
                        // Preview Area
                        VStack(spacing: 0) {
                            if showConsole {
                                VSplitView {
                                    MetalPreviewView()
                                        .frame(minHeight: 400)
                                    
                                    ConsoleView()
                                        .frame(
                                            minHeight: 100,
                                            idealHeight: consoleHeight,
                                            maxHeight: 400
                                        )
                                }
                            } else {
                                MetalPreviewView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Inspector Panel
                        if showInspector {
                            InspectorView()
                                .frame(
                                    minWidth: 280,
                                    idealWidth: inspectorWidth,
                                    maxWidth: 400
                                )
                        }
                    }
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 700)
    }
}

// MARK: - Toolbar
struct ToolbarView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @Binding var showInspector: Bool
    @Binding var showConsole: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side - File info
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(workspace.currentShader?.name ?? "Untitled")
                    .font(.system(size: 13, weight: .medium))
                
                if workspace.hasUnsavedChanges {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Center - Playback controls
            HStack(spacing: 16) {
                Button(action: workspace.resetAnimation) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(ToolbarButtonStyle())
                
                Button(action: workspace.togglePlayback) {
                    Image(systemName: workspace.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(ToolbarButtonStyle())
                .keyboardShortcut(.space, modifiers: [])
                
                Button(action: workspace.captureFrame) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(ToolbarButtonStyle())
            }
            
            Spacer()
            
            // Right side - View toggles
            HStack(spacing: 8) {
                // Performance indicator
                PerformanceIndicator()
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                
                Button(action: { showConsole.toggle() }) {
                    Image(systemName: showConsole ? "terminal.fill" : "terminal")
                        .font(.system(size: 14))
                }
                .buttonStyle(ToolbarButtonStyle())
                
                Button(action: { showInspector.toggle() }) {
                    Image(systemName: showInspector ? "sidebar.right" : "sidebar.right")
                        .font(.system(size: 14))
                        .foregroundColor(showInspector ? .accentColor : .secondary)
                }
                .buttonStyle(ToolbarButtonStyle())
            }
            .padding(.horizontal, 16)
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.16))
    }
}

// MARK: - Shader Editor
struct ShaderEditorView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(workspace.shaderTabs.indices, id: \.self) { index in
                    ShaderTabView(
                        title: workspace.shaderTabs[index].title,
                        isSelected: selectedTab == index
                    ) {
                        selectedTab = index
                    }
                }
                
                Spacer()
                
                Button(action: workspace.addShaderTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
            .frame(height: 30)
            .background(Color(red: 0.13, green: 0.13, blue: 0.14))
            
            // Code editor
            MetalCodeEditor(
                text: Binding(
                    get: { workspace.shaderTabs[safe: selectedTab]?.content ?? "" },
                    set: { 
                        if selectedTab < workspace.shaderTabs.count {
                            workspace.shaderTabs[selectedTab].content = $0
                        }
                        workspace.markAsModified()
                    }
                ),
                language: .metal,
                theme: .professional,
                onTextChange: { workspace.markAsModified() }
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

// MARK: - Metal Preview
struct MetalPreviewView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var viewportSize = CGSize.zero
    @State private var hoveredPosition = CGPoint.zero
    @State private var isHovering = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Checkerboard background
                CheckerboardBackground()
                
                // Metal rendering view
                MetalRenderingView()
                    .aspectRatio(1.0, contentMode: .fit)
                    .frame(maxWidth: min(geometry.size.width * 0.9, geometry.size.height * 0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .onHover { hovering in
                        isHovering = hovering
                    }
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoveredPosition = location
                            workspace.updateMousePosition(location, in: geometry.size)
                        case .ended:
                            break
                        }
                    }
                
                // Overlays
                VStack {
                    HStack {
                        // Performance overlay
                        PerformanceOverlay()
                            .padding(12)
                        
                        Spacer()
                        
                        // Viewport info
                        if isHovering {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("UV: \(String(format: "%.3f, %.3f", hoveredPosition.x / geometry.size.width, hoveredPosition.y / geometry.size.height))")
                                Text("Viewport: \(Int(geometry.size.width))×\(Int(geometry.size.height))")
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                            .padding(12)
                        }
                    }
                    
                    Spacer()
                }
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))
            .onAppear {
                viewportSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                viewportSize = newSize
            }
        }
    }
}

// MARK: - Inspector Panel
struct InspectorView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var selectedSection = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Section selector
            Picker("", selection: $selectedSection) {
                Text("Parameters").tag(0)
                Text("Textures").tag(1)
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
                        TexturesSection()
                    case 2:
                        ExportSection()
                    default:
                        EmptyView()
                    }
                }
                .padding(12)
            }
            
            Divider()
            
            // MCP Connection Status
            MCPConnectionView()
                .padding(12)
        }
        .background(Color(red: 0.13, green: 0.13, blue: 0.14))
    }
}

// MARK: - Parameters Section
struct ParametersSection: View {
    @EnvironmentObject var workspace: WorkspaceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Built-in parameters
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
                }
                .padding(8)
            }
            
            // Custom parameters
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Custom")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: workspace.extractParametersFromShader) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Extract parameters from shader")
                    }
                    
                    ForEach(workspace.customParameters) { parameter in
                        ParameterRow(parameter: parameter, isBuiltin: false)
                    }
                    
                    Button(action: workspace.addCustomParameter) {
                        Label("Add Parameter", systemImage: "plus.circle")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
            }
            
            // Presets
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Presets")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Menu {
                            Button("Save Current", action: workspace.savePreset)
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
    }
}

// MARK: - Parameter Row
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
                                get: { parameter.vectorValue.x },
                                set: { workspace.updateParameter(parameter.id, x: $0) }
                            ),
                            in: parameter.range
                        )
                        .controlSize(.mini)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Y").font(.system(size: 9)).foregroundColor(.secondary)
                        Slider(
                            value: Binding(
                                get: { parameter.vectorValue.y },
                                set: { workspace.updateParameter(parameter.id, y: $0) }
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
            }
        }
        .padding(.vertical, 4)
    }
}

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
        
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        
        // Apply theme
        applyTheme(to: textView)
        
        // Syntax highlighting
        context.coordinator.applySyntaxHighlighting(to: textView)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            textView.string = text
            context.coordinator.applySyntaxHighlighting(to: textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    private func applyTheme(to textView: NSTextView) {
        switch theme {
        case .professional:
            textView.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            textView.textColor = NSColor(red: 0.82, green: 0.82, blue: 0.83, alpha: 1)
            textView.insertionPointColor = .white
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 0.5),
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
            
            // Debounced syntax highlighting
            highlightingQueue.async { [weak self] in
                DispatchQueue.main.async {
                    self?.applySyntaxHighlighting(to: textView)
                }
            }
        }
        
        func applySyntaxHighlighting(to textView: NSTextView) {
            let text = textView.string
            let textStorage = textView.textStorage!
            
            // Reset attributes
            textStorage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: text.count))
            
            // Keywords
            let keywords = ["float", "float2", "float3", "float4", "int", "uint", "bool",
                           "vertex", "fragment", "kernel", "struct", "constant", "device",
                           "using", "namespace", "return", "if", "else", "for", "while"]
            
            for keyword in keywords {
                highlightPattern(keyword, color: .systemBlue, in: textStorage)
            }
            
            // Functions
            let functions = ["sin", "cos", "tan", "pow", "sqrt", "abs", "min", "max",
                           "mix", "clamp", "smoothstep", "length", "normalize", "dot", "cross"]
            
            for function in functions {
                highlightPattern(function, color: .systemPurple, in: textStorage)
            }
            
            // Comments
            highlightPattern("//.*$", color: .systemGreen.withAlphaComponent(0.7), in: textStorage, isRegex: true)
            highlightPattern("/\\*[\\s\\S]*?\\*/", color: .systemGreen.withAlphaComponent(0.7), in: textStorage, isRegex: true)
            
            // Numbers
            highlightPattern("\\b\\d+\\.?\\d*f?\\b", color: .systemOrange, in: textStorage, isRegex: true)
            
            // Strings
            highlightPattern("\"[^\"]*\"", color: .systemRed, in: textStorage, isRegex: true)
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
    @Published var customParameters: [ShaderParameter] = []
    @Published var presets: [ShaderPreset] = []
    
    // Playback
    @Published var isPlaying = true
    @Published var currentFrame = 0
    
    // Performance
    @Published var fps: Double = 0
    @Published var frameTime: Double = 0
    @Published var gpuTime: Double = 0
    
    // Editor state
    @Published var cursorPosition = (line: 1, column: 1)
    @Published var compilationStatus: CompilationStatus = .ready
    @Published var compilationErrors: [CompilationError] = []
    
    // MCP
    @Published var mcpConnected = false
    let mcpServer = MCPServer()
    
    // Renderer
    let renderer: MetalRenderer
    
    private var fileWatcher: FileWatcher?
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
        
        // Initialize renderer
        renderer = MetalRenderer()
        
        // Setup default shader
        setupDefaultShader()
        
        // Start MCP server
        startMCPServer()
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
                case .failure(let errors):
                    self?.compilationStatus = .error
                    self?.compilationErrors = errors
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
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
            if case .vector2(_, let y) = customParameters[index].value {
                customParameters[index].value = .vector2(x, y)
            }
        }
        renderer.updateUniforms(getAllParameterValues())
    }
    
    func updateParameter(_ id: UUID, y: Float) {
        if let index = customParameters.firstIndex(where: { $0.id == id }) {
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
            if let param = customParameters.first(where: { $0.name == key }) {
                param.value = value
            }
        }
        renderer.updateUniforms(preset.parameters)
    }
    
    private func getAllParameterValues() -> [String: ShaderParameter.Value] {
        var values: [String: ShaderParameter.Value] = [:]
        values[timeParameter.name] = timeParameter.value
        values[resolutionParameter.name] = resolutionParameter.value
        
        for param in customParameters {
            values[param.name] = param.value
        }
        
        return values
    }
    
    private func startMCPServer() {
        mcpServer.start { [weak self] connected in
            self?.mcpConnected = connected
        }
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

// MARK: - Metal Renderer
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
        var mouse: SIMD2<Float> = SIMD2<Float>(0, 0)
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
        // Full-screen quad vertices
        let vertices: [Float] = [
            -1, -1, 0, 1,  // bottom left
             1, -1, 1, 1,  // bottom right
            -1,  1, 0, 0,  // top left
             1,  1, 1, 0   // top right
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                        length: vertices.count * MemoryLayout<Float>.size,
                                        options: [])
        
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size,
                                         options: [])
    }
    
    private func compileDefaultShaders() {
        let library = try? device.makeLibrary(source: fullMetalShaderSource, options: nil)
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func compileShader(_ source: String, completion: @escaping (CompilationResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Combine with vertex shader
            let fullSource = vertexShaderSource + "\n\n" + source
            
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
        // Parse Metal compilation errors
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
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState,
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
        uniforms.mouse = SIMD2<Float>(Float(mousePosition.x), Float(mousePosition.y))
        
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
        WorkspaceManager.shared.fps = 60 // Placeholder
        WorkspaceManager.shared.frameTime = 16.67
    }
}

// MARK: - Additional UI Components
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FPS: \(Int(workspace.fps))")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(workspace.fps >= 60 ? .green : .orange)
            
            Text("Frame: \(String(format: "%.2f", workspace.frameTime))ms")
                .font(.system(size: 10, design: .monospaced))
            
            Text("GPU: \(String(format: "%.2f", workspace.gpuTime))ms")
                .font(.system(size: 10, design: .monospaced))
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
        .cornerRadius(6)
        .foregroundColor(.white)
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
        case .compiling: return .orange
        case .success: return .green
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch workspace.compilationStatus {
        case .ready: return "Ready"
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
                            Image(systemName: error.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(error.severity == .error ? .red : .orange)
                            
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
    @State private var exportFormat = "PNG"
    @State private var exportSize = "1920×1080"
    @State private var exportFPS = 60
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Image Export
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Image")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Picker("Format", selection: $exportFormat) {
                        Text("PNG").tag("PNG")
                        Text("JPEG").tag("JPEG")
                        Text("TIFF").tag("TIFF")
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Size", selection: $exportSize) {
                        Text("Current").tag("Current")
                        Text("1920×1080").tag("1920×1080")
                        Text("2560×1440").tag("2560×1440")
                        Text("3840×2160").tag("3840×2160")
                    }
                    .pickerStyle(.menu)
                    
                    Button("Export Image") {
                        // Export image
                    }
                    .controlSize(.small)
                }
                .padding(8)
            }
            
            // Video Export
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Video")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("FPS:")
                        TextField("", value: $exportFPS, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                    
                    Button("Export Video") {
                        // Export video
                    }
                    .controlSize(.small)
                }
                .padding(8)
            }
            
            // Code Export
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Code")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Button("Export to ShaderToy") {
                        // Export to ShaderToy format
                    }
                    .controlSize(.small)
                    
                    Button("Export to Unity") {
                        // Export to Unity format
                    }
                    .controlSize(.small)
                }
                .padding(8)
            }
        }
    }
}

struct MCPConnectionView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(workspace.mcpConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(workspace.mcpConnected ? "MCP Connected" : "MCP Disconnected")
                    .font(.system(size: 11))
                
                Spacer()
                
                Button(workspace.mcpConnected ? "Disconnect" : "Connect") {
                    // Toggle connection
                }
                .controlSize(.mini)
            }
            
            if workspace.mcpConnected {
                Text("Port: 3000")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(6)
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
                
                Text(preset.timestamp.formatted(date: .abbreviated, time: .shortened))
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

// MARK: - Supporting Classes
class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    
    func watch(url: URL, onChange: @escaping () -> Void) {
        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename],
            queue: .main
        )
        
        source?.setEventHandler(handler: onChange)
        source?.setCancelHandler {
            close(fileDescriptor)
        }
        
        source?.resume()
    }
    
    func stop() {
        source?.cancel()
        source = nil
    }
}

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

class MCPServer {
    private var isRunning = false
    
    func start(completion: @escaping (Bool) -> Void) {
        // Simulate MCP server connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isRunning = true
            completion(true)
        }
    }
    
    func stop() {
        isRunning = false
    }
    
    func sendCommand(_ command: String, parameters: [String: Any]) {
        // Send command to MCP server
    }
    
    func receiveUpdate(_ handler: @escaping ([String: Any]) -> Void) {
        // Handle updates from MCP server
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

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              constant float4 *vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = vertices[vertexID];
    out.texCoord = vertices[vertexID].zw;
    return out;
}
"""

let defaultFragmentShader = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
};

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

// MARK: - Extensions
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - HSplitView & VSplitView for macOS
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