import SwiftUI
import MetalKit
import AppKit
import UniformTypeIdentifiers
import Combine
import Network

// MARK: - Main App
// @main removed - using MetalStudioMain.swift as entry point
struct MetalStudioMCPEnhancedApp: App {
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
            
            CommandGroup(replacing: .saveItem) {
                Button("Save Shader") {
                    workspace.saveCurrentShader()
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Button("Export PNG") {
                    workspace.exportImage()
                }
                .keyboardShortcut("e", modifiers: .command)
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
    @State private var inspectorWidth: CGFloat = 360
    @State private var showInspector = true
    @State private var showConsole = false
    @State private var showMCPPanel = true
    @State private var showLibrary = false
    @State private var showGuide = false // Don't show by default
    @State private var consoleHeight: CGFloat = 200
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    
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
                        showConsole: $showConsole,
                        showMCPPanel: $showMCPPanel,
                        showLibrary: $showLibrary,
                        showGuide: $showGuide
                    )
                    .frame(height: 44)
                    
                    Divider()
                        .background(Color.black.opacity(0.5))
                    
                    // Main content area - new layout
                    VSplitView {
                        // Top section: Editor (left) and Preview (right)
                        HSplitView {
                            // Top Left - Shader Editor (always visible)
                            ShaderEditorView()
                                .frame(
                                    minWidth: 350,
                                    idealWidth: editorWidth,
                                    maxWidth: 800
                                )
                            
                            // Top Right - Preview and panels
                            HStack(spacing: 0) {
                                VStack(spacing: 0) {
                                    // Preview (moved up slightly)
                                    MetalPreviewView()
                                        .padding(.top, 8)
                                        .frame(maxHeight: .infinity)
                                    
                                    // Console below preview if enabled
                                    if showConsole && !showLibrary {
                                        Divider()
                                            .background(Color.black.opacity(0.5))
                                        ConsoleView()
                                            .frame(height: 150)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Right Panel - Inspector/MCP (if shown)
                                if showInspector || showMCPPanel {
                                    Divider()
                                        .background(Color.black.opacity(0.5))
                                    
                                    VStack(spacing: 0) {
                                        if showMCPPanel {
                                            MCPControlPanel()
                                                .frame(height: showInspector ? 300 : .infinity)
                                            
                                            if showInspector {
                                                Divider()
                                                    .background(Color.black.opacity(0.5))
                                            }
                                        }
                                        
                                        if showInspector {
                                            InspectorView()
                                                .frame(maxHeight: showMCPPanel ? .infinity : nil)
                                        }
                                    }
                                    .frame(width: 320)
                                }
                            }
                        }
                        .frame(minHeight: showLibrary ? 400 : .infinity)
                        
                        // Bottom section: Library (2/3 width) and Console (1/3 width)
                        if showLibrary {
                            HStack(spacing: 0) {
                                // Library takes 2/3 of width
                                ShaderLibraryView(showLibrary: $showLibrary)
                                    .frame(maxWidth: .infinity)
                                    .frame(minWidth: 400)
                                    .layoutPriority(2)
                                
                                // Console takes remaining 1/3
                                if showConsole {
                                    Divider()
                                        .background(Color.black.opacity(0.5))
                                    
                                    ConsoleView()
                                        .frame(minWidth: 250, maxWidth: 400)
                                        .layoutPriority(1)
                                }
                            }
                            .frame(height: 250)
                        }
                    }
                }
                
                // Guide Overlay - only show when explicitly requested
                if showGuide {
                    GuideOverlay(isShowing: $showGuide)
                        .onDisappear {
                            hasSeenWelcome = true
                        }
                }
            }
        }
        .frame(minWidth: 900, idealWidth: 1200, minHeight: 600, idealHeight: 750)
    }
}

// MARK: - Enhanced Toolbar
struct ToolbarView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @Binding var showInspector: Bool
    @Binding var showConsole: Bool
    @Binding var showMCPPanel: Bool
    @Binding var showLibrary: Bool
    @Binding var showGuide: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side - File info
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(workspace.currentShader?.title ?? "Untitled")
                    .font(.system(size: 13, weight: .medium))
                
                if workspace.hasUnsavedChanges {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Center - Playback controls & Library
            HStack(spacing: 16) {
                // Save button
                Button(action: { workspace.saveShader() }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14))
                }
                .buttonStyle(ToolbarButtonStyle())
                .keyboardShortcut("s", modifiers: .command)
                .help("Save Shader (⌘S)")
                
                // Export Menu
                Menu {
                    Button("Export as PNG...", action: workspace.exportPNG)
                    Button("Export as Video...", action: workspace.exportVideo)
                    Button("Export Shader Code...", action: workspace.exportCode)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
                .help("Export Options")
                
                Divider()
                    .frame(height: 20)
                
                Button(action: { showLibrary.toggle() }) {
                    Image(systemName: showLibrary ? "books.vertical.fill" : "books.vertical")
                        .font(.system(size: 14))
                        .foregroundColor(showLibrary ? .accentColor : .secondary)
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Shader Library")
                
                Divider()
                    .frame(height: 20)
                
                Button(action: { workspace.restartShader() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Restart Shader")
                
                Button(action: { workspace.resetParameters() }) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Reset Parameters")
                
                Button(action: { workspace.togglePlayback() }) {
                    Image(systemName: workspace.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(ToolbarButtonStyle())
                // Removed space shortcut to avoid conflicts with text editing
                
                Button(action: { workspace.captureFrame() }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(ToolbarButtonStyle())
            }
            
            Spacer()
            
            // Right side - View toggles & MCP
            HStack(spacing: 8) {
                // Performance indicator
                PerformanceIndicator()
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                
                // MCP Server Status
                MCPStatusIndicator()
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                
                Button(action: { showGuide.toggle() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14))
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("How to Use Guide")
                
                Button(action: { showConsole.toggle() }) {
                    Image(systemName: showConsole ? "terminal.fill" : "terminal")
                        .font(.system(size: 14))
                }
                .buttonStyle(ToolbarButtonStyle())
                
                Button(action: { showMCPPanel.toggle() }) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 14))
                        .foregroundColor(showMCPPanel ? .accentColor : .secondary)
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("MCP Control Panel")
                
                Button(action: { showInspector.toggle() }) {
                    Image(systemName: "sidebar.right")
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

// MARK: - Shader Library View
struct ShaderLibraryView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @Binding var showLibrary: Bool
    @State private var selectedCategory = "All"
    @State private var searchText = ""
    
    let categories = ["All", "Basic", "Fractals", "Plasma", "Geometric", "Interactive", "3D", "Custom"]
    
    var filteredShaders: [ShaderLibraryItem] {
        workspace.shaderLibrary.filter { shader in
            let matchesCategory = selectedCategory == "All" || shader.category == selectedCategory
            let matchesSearch = searchText.isEmpty || 
                              shader.name.localizedCaseInsensitiveContains(searchText) ||
                              shader.description.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text("SHADER LIBRARY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    
                    TextField("Search shaders...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
                
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            CategoryPill(
                                title: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(red: 0.13, green: 0.13, blue: 0.14))
            
            Divider()
            
            // Shader list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(filteredShaders) { shader in
                        ShaderLibraryCard(shader: shader) {
                            workspace.loadShaderFromLibrary(shader)
                            // Auto-switch back to editor after loading
                            showLibrary = false
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.13))
    }
}

// MARK: - Shader Library Card
struct ShaderLibraryCard: View {
    let shader: ShaderLibraryItem
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shader.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(shader.category)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryColor.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                if shader.hasMouseInteraction {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Button(action: action) {
                    Text("Load")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            
            Text(shader.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Preview thumbnail
            if let preview = shader.previewImage {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 80)
                    .clipped()
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            
            // Performance metrics
            HStack(spacing: 12) {
                Label("\(shader.estimatedFPS) FPS", systemImage: "speedometer")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                
                Label(shader.complexity, systemImage: "cpu")
                    .font(.system(size: 10))
                    .foregroundColor(complexityColor)
            }
        }
        .padding(12)
        .background(isHovered ? Color.white.opacity(0.05) : Color.black.opacity(0.3))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    var categoryColor: Color {
        switch shader.category {
        case "Fractals": return .purple
        case "Plasma": return .orange
        case "Geometric": return .blue
        case "Interactive": return .green
        case "3D": return .red
        default: return .gray
        }
    }
    
    var complexityColor: Color {
        switch shader.complexity {
        case "Low": return .green
        case "Medium": return .orange
        case "High": return .red
        default: return .gray
        }
    }
}

// MARK: - MCP Control Panel
struct MCPControlPanel: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("MCP SERVER", systemImage: "server.rack")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Server control buttons
                HStack(spacing: 8) {
                    if workspace.mcpServer.isRunning {
                        Button(action: { workspace.stopMCPServer() }) {
                            Label("Stop", systemImage: "stop.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { workspace.startMCPServer() }) {
                            Label("Start", systemImage: "play.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(Color(red: 0.14, green: 0.14, blue: 0.15))
            
            // Status Bar
            MCPServerStatusBar()
            
            Divider()
            
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Status").tag(0)
                Text("Functions").tag(1)
                Text("Logs").tag(2)
                Text("Config").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(8)
            
            // Tab content
            ScrollView {
                VStack(spacing: 0) {
                    switch selectedTab {
                    case 0:
                        MCPStatusSection()
                    case 1:
                        MCPFunctionsSection()
                    case 2:
                        MCPLogsSection()
                    case 3:
                        MCPConfigSection()
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

// MARK: - MCP Status Section
struct MCPStatusSection: View {
    @EnvironmentObject var workspace: WorkspaceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Connection info
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("CONNECTION")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    InfoRow(label: "Status", value: workspace.mcpServer.isRunning ? "Running" : "Stopped")
                    InfoRow(label: "Protocol", value: "stdio")
                    InfoRow(label: "Port", value: workspace.mcpServer.port)
                    InfoRow(label: "URL", value: workspace.mcpServer.url)
                    InfoRow(label: "Clients", value: "\(workspace.mcpServer.connectedClients)")
                }
                .padding(8)
            }
            
            // Performance metrics
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PERFORMANCE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    InfoRow(label: "Requests/sec", value: "\(workspace.mcpServer.requestsPerSecond)")
                    InfoRow(label: "Avg Response", value: "\(workspace.mcpServer.avgResponseTime)ms")
                    InfoRow(label: "Memory", value: workspace.mcpServer.memoryUsage)
                    InfoRow(label: "CPU", value: workspace.mcpServer.cpuUsage)
                }
                .padding(8)
            }
            
            // Quick actions
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("QUICK ACTIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Button(action: { workspace.testMCPConnection() }) {
                        Label("Test Connection", systemImage: "network")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { workspace.exportMCPConfig() }) {
                        Label("Export Config", systemImage: "square.and.arrow.up")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { workspace.clearMCPLogs() }) {
                        Label("Clear Logs", systemImage: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
            }
        }
    }
}

// MARK: - MCP Functions Section
struct MCPFunctionsSection: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var expandedFunction: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available MCP tools that LLMs can call:")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            ForEach(workspace.mcpFunctions, id: \.name) { function in
                MCPFunctionCard(
                    function: function,
                    isExpanded: expandedFunction == function.name,
                    onToggle: {
                        withAnimation {
                            expandedFunction = expandedFunction == function.name ? nil : function.name
                        }
                    }
                )
            }
        }
    }
}

// MARK: - MCP Function Card
struct MCPFunctionCard: View {
    let function: MCPFunction
    let isExpanded: Bool
    let onToggle: () -> Void
    @State private var copiedExample = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .frame(width: 12)
                    
                    Image(systemName: function.icon)
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                    
                    Text(function.name)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if function.requiresAuth {
                        Image(systemName: "lock")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Text(function.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Parameters
                    if !function.parameters.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PARAMETERS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ForEach(function.parameters, id: \.name) { param in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(param.name)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.green)
                                    
                                    Text(param.type)
                                        .font(.system(size: 10))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(3)
                                    
                                    if param.required {
                                        Text("required")
                                            .font(.system(size: 9))
                                            .foregroundColor(.red)
                                    }
                                    
                                    Spacer()
                                }
                                
                                Text(param.description)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    
                    // Example usage
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("EXAMPLE")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(function.example, forType: .string)
                                copiedExample = true
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedExample = false
                                }
                            }) {
                                Image(systemName: copiedExample ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 10))
                                    .foregroundColor(copiedExample ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text(function.example)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.3))
        .cornerRadius(6)
    }
}

// MARK: - MCP Logs Section
struct MCPLogsSection: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var filterLevel = "All"
    
    var filteredLogs: [MCPLogEntry] {
        if filterLevel == "All" {
            return workspace.mcpLogs
        }
        return workspace.mcpLogs.filter { $0.level == filterLevel }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Filter
            HStack {
                Text("Filter:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $filterLevel) {
                    Text("All").tag("All")
                    Text("Info").tag("info")
                    Text("Warning").tag("warning")
                    Text("Error").tag("error")
                    Text("Debug").tag("debug")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Spacer()
                
                Button(action: workspace.clearMCPLogs) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            
            // Log entries with auto-scroll
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredLogs) { log in
                            MCPLogRow(log: log)
                                .id(log.id)
                        }
                        
                        // Invisible anchor for scrolling to bottom
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .frame(maxHeight: 300)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
                .onChange(of: filteredLogs.count) { _ in
                    // Auto-scroll to bottom when new logs are added
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onAppear {
                    // Scroll to bottom on initial appearance
                    scrollProxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - MCP Log Row
struct MCPLogRow: View {
    let log: MCPLogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Level indicator
            Circle()
                .fill(levelColor)
                .frame(width: 6, height: 6)
                .padding(.top, 4)
            
            // Timestamp
            Text(log.timestamp.formatted(date: .omitted, time: .standard))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            
            // Message
            Text(log.message)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    var levelColor: Color {
        switch log.level {
        case "info": return .blue
        case "warning": return .orange
        case "error": return .red
        case "debug": return .gray
        default: return .white
        }
    }
}

// MARK: - MCP Config Section
struct MCPConfigSection: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var copiedConfig = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add this configuration to your Claude Desktop settings:")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            // Config JSON
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("claude_desktop_config.json")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(workspace.mcpConfigJSON, forType: .string)
                        copiedConfig = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedConfig = false
                        }
                    }) {
                        Label(copiedConfig ? "Copied!" : "Copy", 
                              systemImage: copiedConfig ? "checkmark.circle" : "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(copiedConfig ? .green : .accentColor)
                    }
                    .buttonStyle(.plain)
                }
                
                ScrollView {
                    Text(workspace.mcpConfigJSON)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(height: 200)
                .background(Color.black.opacity(0.5))
                .cornerRadius(6)
            }
            
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("SETUP INSTRUCTIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                
                InstructionStep(number: 1, text: "Open Claude Desktop settings")
                InstructionStep(number: 2, text: "Navigate to Developer > MCP Servers")
                InstructionStep(number: 3, text: "Add the configuration above")
                InstructionStep(number: 4, text: "Restart Claude Desktop")
                InstructionStep(number: 5, text: "Start the MCP server in this app")
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
        }
    }
}

// MARK: - Guide Overlay
struct GuideOverlay: View {
    @Binding var isShowing: Bool
    @State private var selectedSection = 0
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    
    let sections = [
        ("Getting Started", "rocket"),
        ("Shader Library", "books.vertical"),
        ("Editor & Preview", "chevron.left.forwardslash.chevron.right"),
        ("Parameters", "slider.horizontal.3"),
        ("Mouse Interaction", "hand.tap"),
        ("MCP Connection", "server.rack")
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isShowing = false
                    }
                }
            
            // Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("HOW TO USE METAL STUDIO")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { 
                        withAnimation {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color(red: 0.15, green: 0.15, blue: 0.16))
                
                // Content area
                HStack(spacing: 0) {
                    // Sidebar
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<sections.count, id: \.self) { index in
                            GuideSection(
                                title: sections[index].0,
                                icon: sections[index].1,
                                isSelected: selectedSection == index,
                                action: { selectedSection = index }
                            )
                        }
                        
                        Spacer()
                    }
                    .frame(width: 200)
                    .padding(16)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.13))
                    
                    // Content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            switch selectedSection {
                            case 0:
                                GettingStartedGuide()
                            case 1:
                                ShaderLibraryGuide()
                            case 2:
                                EditorPreviewGuide()
                            case 3:
                                ParametersGuide()
                            case 4:
                                MouseInteractionGuide()
                            case 5:
                                MCPConnectionGuide()
                            default:
                                EmptyView()
                            }
                        }
                        .padding(24)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 500)
            }
            .frame(width: 800)
            .background(Color(red: 0.13, green: 0.13, blue: 0.14))
            .cornerRadius(12)
            .shadow(radius: 30)
        }
    }
}

// MARK: - Guide Content Sections
struct GettingStartedGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🎨 Welcome to Metal Studio MCP Enhanced")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Your professional Metal shader development environment with live preview and AI integration.")
                .font(.system(size: 14))
                .foregroundColor(.white)
            
            // Quick Start section
            VStack(alignment: .leading, spacing: 12) {
                Text("QUICK START")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                
                HStack(alignment: .top, spacing: 12) {
                    Text("1.")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Try the Shader Library")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Click the books icon in the toolbar to browse pre-built shaders")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Text("2.")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Edit and See Changes Live")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Type in the code editor - your changes compile automatically")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Text("3.")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Interact with Your Shader")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Move your mouse over the preview - many shaders respond to interaction")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            
            Divider()
            
            GuideFeature(
                icon: "cpu",
                title: "Real-time Compilation",
                description: "Write Metal shaders and see results instantly with hot-reload support"
            )
            
            GuideFeature(
                icon: "eye",
                title: "Live Preview",
                description: "60+ FPS preview with mouse interaction and parameter controls"
            )
            
            GuideFeature(
                icon: "server.rack",
                title: "MCP Integration",
                description: "Connect Claude or other LLMs to control shaders programmatically"
            )
            
            GuideFeature(
                icon: "books.vertical",
                title: "Shader Library",
                description: "Built-in collection of example shaders to learn from and modify"
            )
        }
    }
}

struct MCPConnectionGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Connecting to MCP Server")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("The MCP (Model Context Protocol) server allows AI assistants like Claude to interact with your shader environment.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                GuideStep(number: 1, title: "Start the Server", 
                         description: "Click the play button in the MCP panel to start the server")
                
                GuideStep(number: 2, title: "Copy Configuration", 
                         description: "Go to Config tab and copy the JSON configuration")
                
                GuideStep(number: 3, title: "Add to Claude Desktop", 
                         description: "Open Claude Desktop settings and add the MCP server config")
                
                GuideStep(number: 4, title: "Test Connection", 
                         description: "Ask Claude to compile a shader or update parameters")
            }
            
            // Example command
            VStack(alignment: .leading, spacing: 8) {
                Text("Example Claude Command:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                
                Text("\"Create a colorful plasma effect shader with mouse interaction\"")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - Metal Preview View with Mouse Visualization
struct MetalPreviewView: View {
    @EnvironmentObject var workspace: WorkspaceManager
    @State private var viewportSize = CGSize.zero
    @State private var hoveredPosition = CGPoint.zero
    @State private var isHovering = false
    @State private var mouseDown = false
    
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
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                mouseDown = true
                                hoveredPosition = value.location
                                workspace.updateMousePosition(value.location, in: geometry.size)
                            }
                            .onEnded { _ in
                                mouseDown = false
                            }
                    )
                
                // Mouse visualization overlay
                if isHovering || mouseDown {
                    MouseVisualizationOverlay(
                        position: hoveredPosition,
                        isPressed: mouseDown,
                        viewportSize: geometry.size
                    )
                    .allowsHitTesting(false)
                }
                
                // Overlays
                VStack {
                    HStack {
                        // Performance overlay
                        PerformanceOverlay()
                            .padding(12)
                        
                        Spacer()
                        
                        // Mouse coordinates
                        if isHovering {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Mouse: \(String(format: "%.3f, %.3f", hoveredPosition.x / geometry.size.width, hoveredPosition.y / geometry.size.height))")
                                Text("UV: \(String(format: "%.3f, %.3f", hoveredPosition.x / geometry.size.width, 1.0 - hoveredPosition.y / geometry.size.height))")
                                Text("Viewport: \(Int(geometry.size.width))×\(Int(geometry.size.height))")
                                if mouseDown {
                                    Text("PRESSED")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 10, weight: .bold))
                                }
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

// MARK: - Mouse Visualization Overlay
struct MouseVisualizationOverlay: View {
    let position: CGPoint
    let isPressed: Bool
    let viewportSize: CGSize
    
    var body: some View {
        ZStack {
            // Crosshair
            Path { path in
                // Horizontal line
                path.move(to: CGPoint(x: 0, y: position.y))
                path.addLine(to: CGPoint(x: viewportSize.width, y: position.y))
                
                // Vertical line
                path.move(to: CGPoint(x: position.x, y: 0))
                path.addLine(to: CGPoint(x: position.x, y: viewportSize.height))
            }
            .stroke(
                Color.white.opacity(0.3),
                style: StrokeStyle(lineWidth: 1, dash: [5, 5])
            )
            
            // Mouse cursor indicator
            Circle()
                .stroke(isPressed ? Color.orange : Color.white, lineWidth: 2)
                .frame(width: isPressed ? 20 : 16, height: isPressed ? 20 : 16)
                .position(position)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
            
            // Ripple effect when pressed
            if isPressed {
                Circle()
                    .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .position(position)
                    .scaleEffect(isPressed ? 1.5 : 1.0)
                    .opacity(isPressed ? 0 : 1)
                    .animation(.easeOut(duration: 0.3), value: isPressed)
            }
        }
    }
}

// MARK: - Supporting Components
struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.white)
        }
    }
}

struct GuideSection: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct GuideFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct GuideStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 24, height: 24)
                
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct MCPStatusIndicator: View {
    @EnvironmentObject var workspace: WorkspaceManager
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(workspace.mcpServer.isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(workspace.mcpServer.isRunning ? Color.green : Color.red, lineWidth: 8)
                        .opacity(workspace.mcpServer.isRunning ? 0.3 : 0)
                        .scaleEffect(workspace.mcpServer.isRunning ? 2 : 1)
                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), 
                                 value: workspace.mcpServer.isRunning)
            )
            
            Text("MCP")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(workspace.mcpServer.isRunning ? .white : .secondary)
        }
    }
}

struct MCPServerStatusBar: View {
    @EnvironmentObject var workspace: WorkspaceManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Status
            HStack(spacing: 4) {
                Circle()
                    .fill(workspace.mcpServer.isRunning ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(workspace.mcpServer.isRunning ? "Running" : "Stopped")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 12)
            
            // Port
            Text("Port: \(workspace.mcpServer.port)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            
            // Clients
            Text("Clients: \(workspace.mcpServer.connectedClients)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Activity indicator
            if workspace.mcpServer.isProcessing {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.3))
    }
}

// Extension removed - method already exists in WorkspaceManager in MetalStudioMCPCore.swift

// [Previous code continues with all the original components from MetalStudioProfessional.swift...]
// Including: ShaderEditorView, InspectorView, ParametersSection, MetalRenderer, etc.