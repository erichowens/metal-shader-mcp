#!/usr/bin/env swift

/**
 * Metal Studio MCP - Professional Metal Shader Development with MCP Integration
 * Shows MCP tools and server status
 */

import Cocoa
import Metal
import MetalKit
import simd
import Foundation

// MARK: - MCP Tool Definitions

struct MCPTool {
    let id: String
    let name: String
    let description: String
    let status: String
}

let mcpTools = [
    MCPTool(
        id: "hot-reload",
        name: "Hot Reload Monitor",
        description: "Watches shader files for changes and automatically recompiles",
        status: "ready"
    ),
    MCPTool(
        id: "param-extractor", 
        name: "Parameter Extractor",
        description: "Analyzes shaders to extract tunable parameters",
        status: "ready"
    ),
    MCPTool(
        id: "shader-library",
        name: "Shader Library Manager",
        description: "Manages and organizes shader templates",
        status: "ready"
    ),
    MCPTool(
        id: "performance-profiler",
        name: "Performance Profiler",
        description: "Measures FPS, GPU usage, and memory consumption",
        status: "ready"
    ),
    MCPTool(
        id: "shader-validator",
        name: "Shader Validator",
        description: "Validates Metal shader syntax and compatibility",
        status: "ready"
    ),
    MCPTool(
        id: "export-generator",
        name: "Export Generator",
        description: "Generates production-ready Swift/ObjC code",
        status: "ready"
    ),
    MCPTool(
        id: "version-control",
        name: "Version Control",
        description: "Manages shader versions and history",
        status: "ready"
    )
]

// MARK: - Shader Templates

struct ShaderTemplate {
    let name: String
    let source: String
    let parameters: [ParameterDefinition]
}

struct ParameterDefinition {
    let name: String
    let label: String
    let min: Float
    let max: Float
    let defaultValue: Float
    let uniformName: String
}

// MARK: - Dynamic Uniforms

struct DynamicUniforms {
    var time: Float = 0
    var resolution: SIMD2<Float> = SIMD2<Float>(800, 600)
    var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    var param1: Float = 0.5
    var param2: Float = 0.5
    var param3: Float = 0.5
    var param4: Float = 0.5
    var param5: Float = 0.5
    var param6: Float = 0.5
    var param7: Float = 0.5
    var param8: Float = 0.5
}

// MARK: - Shader Library

class ShaderLibrary {
    static let templates = [
        ShaderTemplate(
            name: "Gradient",
            source: """
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
    float param1; // angle
    float param2; // color_shift
    float param3; // wave_amount
    float param4; // smoothness
    float param5;
    float param6;
    float param7;
    float param8;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 positions[4] = {
        float2(-1, -1), float2(1, -1),
        float2(-1, 1), float2(1, 1)
    };
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = (positions[vertexID] + 1.0) * 0.5;
    return out;
}

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Rotate gradient by angle
    float angle = u.param1 * 3.14159 * 2.0;
    float2 dir = float2(cos(angle), sin(angle));
    float gradient = dot(uv - 0.5, dir) + 0.5;
    
    // Add wave distortion
    gradient += sin(gradient * 10.0 + u.time) * u.param3 * 0.1;
    
    // Apply smoothness
    gradient = smoothstep(0.0, u.param4, gradient);
    
    // Color with shift
    float3 color1 = float3(1.0, 0.2, 0.1);
    float3 color2 = float3(0.1, 0.8, 0.3);
    float3 color = mix(color1, color2, gradient);
    
    // Apply color shift over time
    color = mix(color, color.gbr, u.param2);
    
    return float4(color, 1.0);
}
""",
            parameters: [
                ParameterDefinition(name: "angle", label: "Angle", min: 0, max: 1, defaultValue: 0.25, uniformName: "param1"),
                ParameterDefinition(name: "colorShift", label: "Color Shift", min: 0, max: 1, defaultValue: 0.0, uniformName: "param2"),
                ParameterDefinition(name: "wave", label: "Wave", min: 0, max: 1, defaultValue: 0.0, uniformName: "param3"),
                ParameterDefinition(name: "smoothness", label: "Smoothness", min: 0.1, max: 1, defaultValue: 0.7, uniformName: "param4")
            ]
        ),
        ShaderTemplate(
            name: "Plasma",
            source: """
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
    float param1; // frequency
    float param2; // amplitude
    float param3; // speed
    float param4; // color_cycle
    float param5;
    float param6;
    float param7;
    float param8;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 positions[4] = {
        float2(-1, -1), float2(1, -1),
        float2(-1, 1), float2(1, 1)
    };
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = (positions[vertexID] + 1.0) * 0.5;
    return out;
}

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    float2 p = (in.texCoord - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float freq = u.param1 * 20.0;
    float amp = u.param2;
    float speed = u.param3 * 5.0;
    
    float plasma = 0.0;
    plasma += sin(p.x * freq + u.time * speed) * amp;
    plasma += sin(p.y * freq * 0.8 - u.time * speed * 0.5) * amp;
    plasma += sin(length(p * freq * 0.5) - u.time * speed * 2.0) * amp;
    plasma /= 3.0;
    
    float3 color;
    float cycle = u.param4 * 6.28318;
    color.r = sin(plasma * 3.14159 + cycle) * 0.5 + 0.5;
    color.g = sin(plasma * 3.14159 + 2.094 + cycle) * 0.5 + 0.5;
    color.b = sin(plasma * 3.14159 + 4.189 + cycle) * 0.5 + 0.5;
    
    return float4(color, 1.0);
}
""",
            parameters: [
                ParameterDefinition(name: "frequency", label: "Frequency", min: 0.1, max: 1, defaultValue: 0.5, uniformName: "param1"),
                ParameterDefinition(name: "amplitude", label: "Amplitude", min: 0.1, max: 2, defaultValue: 1.0, uniformName: "param2"),
                ParameterDefinition(name: "speed", label: "Speed", min: 0, max: 1, defaultValue: 0.2, uniformName: "param3"),
                ParameterDefinition(name: "colorCycle", label: "Color Cycle", min: 0, max: 1, defaultValue: 0, uniformName: "param4")
            ]
        )
    ]
}

// MARK: - Metal Preview View

class MetalPreviewView: MTKView {
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState?
    var startTime = Date()
    var uniforms = DynamicUniforms()
    var lastError: String?
    var currentTemplate: ShaderTemplate?
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        setupMetal()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1)
        colorPixelFormat = .bgra8Unorm
        drawableSize = CGSize(width: 600, height: 600)
        delegate = self
        isPaused = false
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 60
    }
    
    func loadShader(_ source: String) -> Bool {
        do {
            let library = try device?.makeLibrary(source: source, options: nil)
            let vertexFunction = library?.makeFunction(name: "vertexShader")
            let fragmentFunction = library?.makeFunction(name: "fragmentShader")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
            
            pipelineState = try device?.makeRenderPipelineState(descriptor: pipelineDescriptor)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    
    func setParameterValue(_ value: Float, at index: Int) {
        switch index {
        case 0: uniforms.param1 = value
        case 1: uniforms.param2 = value
        case 2: uniforms.param3 = value
        case 3: uniforms.param4 = value
        case 4: uniforms.param5 = value
        case 5: uniforms.param6 = value
        case 6: uniforms.param7 = value
        case 7: uniforms.param8 = value
        default: break
        }
    }
}

extension MetalPreviewView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
    }
    
    func draw(in view: MTKView) {
        guard let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              let pipelineState = pipelineState else { return }
        
        uniforms.time = Float(Date().timeIntervalSince(startTime))
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        
        var uniformData = uniforms
        encoder.setFragmentBytes(&uniformData, length: MemoryLayout<DynamicUniforms>.size, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - MCP Server Manager

class MCPServerManager {
    static let shared = MCPServerManager()
    private var serverProcess: Process?
    var isRunning = false
    var statusCallback: ((Bool, String) -> Void)?
    
    func checkServerStatus() -> (running: Bool, port: Int?) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "lsof -i :3000 | grep LISTEN"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if !output.isEmpty && output.contains("node") {
                return (true, 3000)
            }
        } catch {}
        
        return (false, nil)
    }
    
    func startServer() {
        guard !isRunning else { return }
        
        // Check if package.json exists
        let packagePath = "/Users/erichowens/coding/metal-shader-mcp/package.json"
        if !FileManager.default.fileExists(atPath: packagePath) {
            statusCallback?(false, "No package.json found. Run 'npm init' first.")
            return
        }
        
        serverProcess = Process()
        serverProcess?.currentDirectoryPath = "/Users/erichowens/coding/metal-shader-mcp"
        serverProcess?.launchPath = "/usr/bin/env"
        serverProcess?.arguments = ["npm", "run", "mcp:dev"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        serverProcess?.standardOutput = outputPipe
        serverProcess?.standardError = errorPipe
        
        do {
            try serverProcess?.run()
            isRunning = true
            statusCallback?(true, "MCP Server starting on port 3000...")
            
            // Monitor output
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    DispatchQueue.main.async {
                        self.statusCallback?(true, "Server: \(output)")
                    }
                }
            }
        } catch {
            statusCallback?(false, "Failed to start server: \(error.localizedDescription)")
        }
    }
    
    func stopServer() {
        serverProcess?.terminate()
        serverProcess = nil
        isRunning = false
        statusCallback?(false, "MCP Server stopped")
    }
}

// MARK: - Main Application

class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var editorView: NSTextView!
    var previewView: MetalPreviewView!
    var statusLabel: NSTextField!
    var templateSelector: NSPopUpButton!
    var parameterViews: [NSView] = []
    var mcpPanel: NSView!
    var mcpStatusLabel: NSTextField!
    var mcpToolsTable: NSTableView!
    var mcpServerButton: NSButton!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1600, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Studio MCP - Professional Shader Development"
        window.minSize = NSSize(width: 1400, height: 800)
        
        setupMainLayout()
        
        setupBottomToolbar()
        
        // Load first template and setup MCP
        selectTemplate(at: 0)
        setupMCPManager()
        
        window.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - Layout Setup
    
    func setupMainLayout() {
        guard let contentView = window.contentView else { return }
        
        // Define layout constants
        let margin: CGFloat = 16
        let panelSpacing: CGFloat = 12
        let toolbarHeight: CGFloat = 60
        
        let windowWidth = contentView.bounds.width
        let windowHeight = contentView.bounds.height
        
        // Calculate panel widths (3-column layout)
        let editorWidth: CGFloat = 480
        let previewWidth: CGFloat = 500
        let controlsWidth = windowWidth - editorWidth - previewWidth - (margin * 4) - (panelSpacing * 2)
        
        // Left Panel: Code Editor
        setupEditorPanel(frame: NSRect(
            x: margin,
            y: toolbarHeight + margin,
            width: editorWidth,
            height: windowHeight - toolbarHeight - (margin * 2)
        ))
        
        // Center Panel: Preview
        setupPreviewPanel(frame: NSRect(
            x: margin + editorWidth + panelSpacing,
            y: toolbarHeight + margin,
            width: previewWidth,
            height: windowHeight - toolbarHeight - (margin * 2)
        ))
        
        // Right Panel: Controls (split into Parameters and MCP)
        setupControlsPanel(frame: NSRect(
            x: margin + editorWidth + panelSpacing + previewWidth + panelSpacing,
            y: toolbarHeight + margin,
            width: controlsWidth,
            height: windowHeight - toolbarHeight - (margin * 2)
        ))
    }
    
    func setupEditorPanel(frame: NSRect) {
        // Panel background
        let editorPanel = NSView(frame: frame)
        editorPanel.wantsLayer = true
        editorPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        editorPanel.layer?.cornerRadius = 8
        window.contentView?.addSubview(editorPanel)
        
        // Header
        let headerHeight: CGFloat = 32
        let header = NSView(frame: NSRect(x: 0, y: frame.height - headerHeight, width: frame.width, height: headerHeight))
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor.headerColor.cgColor
        editorPanel.addSubview(header)
        
        let headerLabel = NSTextField(labelWithString: "Shader Editor")
        headerLabel.frame = NSRect(x: 12, y: 8, width: 120, height: 16)
        headerLabel.font = .boldSystemFont(ofSize: 13)
        headerLabel.textColor = .headerTextColor
        header.addSubview(headerLabel)
        
        // Template selector in header
        templateSelector = NSPopUpButton(frame: NSRect(x: frame.width - 180, y: 4, width: 160, height: 24))
        for template in ShaderLibrary.templates {
            templateSelector.addItem(withTitle: template.name)
        }
        templateSelector.target = self
        templateSelector.action = #selector(templateSelected)
        header.addSubview(templateSelector)
        
        // Editor scroll view
        let scrollView = NSScrollView(frame: NSRect(
            x: 8,
            y: 8,
            width: frame.width - 16,
            height: frame.height - headerHeight - 16
        ))
        
        editorView = NSTextView(frame: scrollView.bounds)
        editorView.autoresizingMask = [.width, .height]
        editorView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        editorView.isAutomaticQuoteSubstitutionEnabled = false
        editorView.isRichText = false
        editorView.backgroundColor = NSColor(white: 0.06, alpha: 1.0)
        editorView.textColor = .textColor
        editorView.delegate = self
        editorView.textContainerInset = NSSize(width: 12, height: 12)
        
        scrollView.documentView = editorView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        editorPanel.addSubview(scrollView)
    }
    
    func setupPreviewPanel(frame: NSRect) {
        // Panel background
        let previewPanel = NSView(frame: frame)
        previewPanel.wantsLayer = true
        previewPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        previewPanel.layer?.cornerRadius = 8
        window.contentView?.addSubview(previewPanel)
        
        // Header
        let headerHeight: CGFloat = 32
        let header = NSView(frame: NSRect(x: 0, y: frame.height - headerHeight, width: frame.width, height: headerHeight))
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor.headerColor.cgColor
        previewPanel.addSubview(header)
        
        let headerLabel = NSTextField(labelWithString: "Live Preview")
        headerLabel.frame = NSRect(x: 12, y: 8, width: 120, height: 16)
        headerLabel.font = .boldSystemFont(ofSize: 13)
        headerLabel.textColor = .headerTextColor
        header.addSubview(headerLabel)
        
        // FPS counter in header
        let fpsLabel = NSTextField(labelWithString: "FPS: 0")
        fpsLabel.frame = NSRect(x: frame.width - 80, y: 8, width: 60, height: 16)
        fpsLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        fpsLabel.textColor = .systemOrange
        header.addSubview(fpsLabel)
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            fpsLabel.stringValue = String(format: "FPS: %.0f", 
                1.0 / (self.previewView.currentDrawable?.presentedTime ?? 0.016))
        }
        
        // Preview view (centered and square)
        let previewSize: CGFloat = min(frame.width - 32, frame.height - headerHeight - 32)
        let previewX = (frame.width - previewSize) / 2
        let previewY = (frame.height - headerHeight - previewSize) / 2
        
        previewView = MetalPreviewView(frame: NSRect(
            x: previewX,
            y: previewY,
            width: previewSize,
            height: previewSize
        ))
        previewView.layer?.cornerRadius = 6
        previewView.layer?.borderWidth = 1
        previewView.layer?.borderColor = NSColor.separatorColor.cgColor
        previewPanel.addSubview(previewView)
    }
    
    func setupControlsPanel(frame: NSRect) {
        // Split controls panel into Parameters (top) and MCP Tools (bottom)
        let splitHeight = frame.height / 2 - 6
        
        // Parameters Panel (top half)
        setupParametersPanel(frame: NSRect(
            x: frame.minX,
            y: frame.minY + splitHeight + 12,
            width: frame.width,
            height: splitHeight
        ))
        
        // MCP Panel (bottom half) - compact design
        createMCPPanel(frame: NSRect(
            x: frame.minX,
            y: frame.minY,
            width: frame.width,
            height: splitHeight
        ))
    }
    
    func setupParametersPanel(frame: NSRect) {
        // Parameters panel background
        let paramPanel = NSView(frame: frame)
        paramPanel.wantsLayer = true
        paramPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        paramPanel.layer?.cornerRadius = 8
        window.contentView?.addSubview(paramPanel)
        
        // Header
        let headerHeight: CGFloat = 32
        let header = NSView(frame: NSRect(x: 0, y: frame.height - headerHeight, width: frame.width, height: headerHeight))
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor.headerColor.cgColor
        paramPanel.addSubview(header)
        
        let headerLabel = NSTextField(labelWithString: "Shader Parameters")
        headerLabel.frame = NSRect(x: 12, y: 8, width: 150, height: 16)
        headerLabel.font = .boldSystemFont(ofSize: 13)
        headerLabel.textColor = .headerTextColor
        header.addSubview(headerLabel)
        
        // Store parameter panel reference for dynamic controls
        paramPanel.identifier = NSUserInterfaceItemIdentifier("parameterPanel")
    }
    
    func setupBottomToolbar() {
        // Bottom toolbar background
        let toolbarHeight: CGFloat = 60
        let toolbar = NSView(frame: NSRect(x: 0, y: 0, width: window.contentView!.bounds.width, height: toolbarHeight))
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        toolbar.autoresizingMask = [.width]
        
        // Add separator line
        let separator = NSView(frame: NSRect(x: 0, y: toolbarHeight - 1, width: toolbar.bounds.width, height: 1))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.autoresizingMask = [.width]
        toolbar.addSubview(separator)
        
        // Action buttons
        let buttonWidth: CGFloat = 90
        let buttonHeight: CGFloat = 32
        let buttonY = (toolbarHeight - buttonHeight) / 2
        let buttonSpacing: CGFloat = 12
        var buttonX: CGFloat = 16
        
        let compileButton = NSButton(title: "Compile", target: self, action: #selector(compileShader))
        compileButton.frame = NSRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight)
        compileButton.bezelStyle = .rounded
        compileButton.keyEquivalent = "\r"
        toolbar.addSubview(compileButton)
        buttonX += buttonWidth + buttonSpacing
        
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveShader))
        saveButton.frame = NSRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = .command
        toolbar.addSubview(saveButton)
        buttonX += buttonWidth + buttonSpacing
        
        let loadButton = NSButton(title: "Load", target: self, action: #selector(loadShader))
        loadButton.frame = NSRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight)
        loadButton.bezelStyle = .rounded
        loadButton.keyEquivalent = "o"
        loadButton.keyEquivalentModifierMask = .command
        toolbar.addSubview(loadButton)
        buttonX += buttonWidth + buttonSpacing
        
        let exportButton = NSButton(title: "Export Swift", target: self, action: #selector(exportCode))
        exportButton.frame = NSRect(x: buttonX, y: buttonY, width: buttonWidth + 20, height: buttonHeight)
        exportButton.bezelStyle = .rounded
        toolbar.addSubview(exportButton)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.frame = NSRect(
            x: buttonX + buttonWidth + 40,
            y: buttonY + 8,
            width: 400,
            height: 16
        )
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        toolbar.addSubview(statusLabel)
        
        window.contentView?.addSubview(toolbar)
    }
    
    func setupMCPManager() {
        MCPServerManager.shared.statusCallback = { [weak self] running, message in
            DispatchQueue.main.async {
                self?.updateMCPStatus(running: running, message: message)
            }
        }
        checkMCPServerStatus()
    }
    
    func createMCPPanel(frame: NSRect) {
        // MCP Panel container with improved compact design
        mcpPanel = NSView(frame: frame)
        mcpPanel.wantsLayer = true
        mcpPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        mcpPanel.layer?.cornerRadius = 8
        
        // Header
        let headerHeight: CGFloat = 32
        let header = NSView(frame: NSRect(x: 0, y: frame.height - headerHeight, width: frame.width, height: headerHeight))
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor.headerColor.cgColor
        mcpPanel.addSubview(header)
        
        let headerLabel = NSTextField(labelWithString: "MCP Tools & Server")
        headerLabel.frame = NSRect(x: 12, y: 8, width: 150, height: 16)
        headerLabel.font = .boldSystemFont(ofSize: 13)
        headerLabel.textColor = .headerTextColor
        header.addSubview(headerLabel)
        
        // Server status in header
        mcpStatusLabel = NSTextField(labelWithString: "Checking...")
        mcpStatusLabel.frame = NSRect(x: 170, y: 8, width: frame.width - 340, height: 16)
        mcpStatusLabel.font = .systemFont(ofSize: 11)
        mcpStatusLabel.textColor = .systemOrange
        mcpStatusLabel.isBordered = false
        mcpStatusLabel.backgroundColor = .clear
        header.addSubview(mcpStatusLabel)
        
        // Start/Stop button in header
        mcpServerButton = NSButton(title: "Start Server", target: self, action: #selector(toggleMCPServer))
        mcpServerButton.frame = NSRect(x: frame.width - 120, y: 4, width: 108, height: 24)
        mcpServerButton.bezelStyle = .rounded
        mcpServerButton.controlSize = .small
        header.addSubview(mcpServerButton)
        
        // Compact tools grid (3 columns instead of table)
        setupMCPToolsGrid()
        
        // Quick status info at bottom
        setupMCPStatusInfo()
        
        window.contentView?.addSubview(mcpPanel)
    }
    
    func setupMCPToolsGrid() {
        let gridStartY: CGFloat = mcpPanel.frame.height - 64
        let itemWidth: CGFloat = (mcpPanel.frame.width - 48) / 3 // 3 columns with margins
        let itemHeight: CGFloat = 60
        let margin: CGFloat = 12
        
        // Create compact tool cards in 3-column grid
        for (index, tool) in mcpTools.enumerated() {
            let row = index / 3
            let col = index % 3
            
            let x = margin + CGFloat(col) * (itemWidth + 8)
            let y = gridStartY - CGFloat(row) * (itemHeight + 8) - 32
            
            if y > 40 { // Only show if it fits
                let toolCard = createToolCard(tool: tool, frame: NSRect(x: x, y: y, width: itemWidth, height: itemHeight))
                mcpPanel.addSubview(toolCard)
            }
        }
    }
    
    func createToolCard(tool: MCPTool, frame: NSRect) -> NSView {
        let card = NSView(frame: frame)
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.1).cgColor
        card.layer?.cornerRadius = 6
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Status indicator (top-right)
        let statusDot = NSView(frame: NSRect(x: frame.width - 16, y: frame.height - 16, width: 8, height: 8))
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4
        statusDot.layer?.backgroundColor = MCPServerManager.shared.isRunning ? 
            NSColor.systemGreen.cgColor : NSColor.systemGray.cgColor
        card.addSubview(statusDot)
        
        // Tool name
        let nameLabel = NSTextField(labelWithString: tool.name)
        nameLabel.frame = NSRect(x: 8, y: frame.height - 20, width: frame.width - 24, height: 14)
        nameLabel.font = .boldSystemFont(ofSize: 10)
        nameLabel.textColor = .labelColor
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        card.addSubview(nameLabel)
        
        // Tool description (truncated)
        let description = tool.description.count > 40 ? 
            String(tool.description.prefix(37)) + "..." : tool.description
        let descLabel = NSTextField(labelWithString: description)
        descLabel.frame = NSRect(x: 8, y: 8, width: frame.width - 16, height: 28)
        descLabel.font = .systemFont(ofSize: 9)
        descLabel.textColor = .secondaryLabelColor
        descLabel.isBordered = false
        descLabel.backgroundColor = .clear
        descLabel.cell?.wraps = true
        descLabel.cell?.isScrollable = false
        card.addSubview(descLabel)
        
        return card
    }
    
    func setupMCPStatusInfo() {
        // Compact configuration info at bottom
        let infoY: CGFloat = 8
        
        let configInfo = NSTextField(labelWithString: "Port: 3000 • JSON-RPC 2.0 • stdio/HTTP")
        configInfo.frame = NSRect(x: 12, y: infoY, width: mcpPanel.frame.width - 24, height: 16)
        configInfo.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        configInfo.textColor = .tertiaryLabelColor
        configInfo.isBordered = false
        configInfo.backgroundColor = .clear
        mcpPanel.addSubview(configInfo)
        
        let statusInfo = NSTextField(labelWithString: "Tools available when server is running")
        statusInfo.frame = NSRect(x: 12, y: infoY + 16, width: mcpPanel.frame.width - 24, height: 14)
        statusInfo.font = .systemFont(ofSize: 10)
        statusInfo.textColor = .tertiaryLabelColor
        statusInfo.isBordered = false
        statusInfo.backgroundColor = .clear
        mcpPanel.addSubview(statusInfo)
    }
    
    func checkMCPServerStatus() {
        let status = MCPServerManager.shared.checkServerStatus()
        if status.running {
            updateMCPStatus(running: true, message: "Server running on port \(status.port ?? 3000)")
            mcpServerButton.title = "Stop Server"
        } else {
            updateMCPStatus(running: false, message: "Server not running")
            mcpServerButton.title = "Start Server"
        }
    }
    
    func updateMCPStatus(running: Bool, message: String) {
        mcpStatusLabel.stringValue = message
        mcpStatusLabel.textColor = running ? .systemGreen : .systemOrange
        mcpServerButton.title = running ? "Stop Server" : "Start Server"
        MCPServerManager.shared.isRunning = running
        
        // Update tool status dots
        updateMCPToolCards()
    }
    
    func updateMCPToolCards() {
        // Update status dots in tool cards
        for subview in mcpPanel.subviews {
            if let statusDot = subview.subviews.first(where: { $0.frame.width == 8 && $0.frame.height == 8 }) {
                statusDot.layer?.backgroundColor = MCPServerManager.shared.isRunning ? 
                    NSColor.systemGreen.cgColor : NSColor.systemGray.cgColor
            }
        }
    }
    
    @objc func toggleMCPServer() {
        if MCPServerManager.shared.isRunning {
            MCPServerManager.shared.stopServer()
        } else {
            MCPServerManager.shared.startServer()
        }
    }
    
    func selectTemplate(at index: Int) {
        let template = ShaderLibrary.templates[index]
        editorView.string = template.source
        previewView.currentTemplate = template
        
        setupParameterControls(for: template)
        compileShader()
    }
    
    func setupParameterControls(for template: ShaderTemplate) {
        // Clear old parameter controls
        for view in parameterViews {
            view.removeFromSuperview()
        }
        parameterViews.removeAll()
        
        // Find the parameter panel
        guard let paramPanel = window.contentView?.subviews.first(where: { 
            $0.identifier?.rawValue == "parameterPanel" 
        }) else { return }
        
        // Create parameter controls inside the parameter panel
        let contentY = paramPanel.frame.height - 44 // Below header
        let itemHeight: CGFloat = 32
        let margin: CGFloat = 12
        
        for (i, param) in template.parameters.enumerated() {
            let y = contentY - CGFloat(i + 1) * (itemHeight + 8)
            
            if y > margin { // Only create if it fits
                // Parameter label
                let label = NSTextField(labelWithString: param.label)
                label.frame = NSRect(x: margin, y: y + 8, width: 80, height: 16)
                label.font = .systemFont(ofSize: 11, weight: .medium)
                label.textColor = .labelColor
                label.isBordered = false
                label.backgroundColor = .clear
                paramPanel.addSubview(label)
                parameterViews.append(label)
                
                // Value label
                let valueLabel = NSTextField(labelWithString: String(format: "%.2f", param.defaultValue))
                valueLabel.frame = NSRect(x: paramPanel.frame.width - 50, y: y + 8, width: 40, height: 16)
                valueLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
                valueLabel.textColor = .secondaryLabelColor
                valueLabel.tag = 1000 + i
                valueLabel.isBordered = false
                valueLabel.backgroundColor = .clear
                valueLabel.alignment = .right
                paramPanel.addSubview(valueLabel)
                parameterViews.append(valueLabel)
                
                // Parameter slider
                let sliderWidth = paramPanel.frame.width - margin * 2 - 90 - 50
                let slider = NSSlider(
                    value: Double(param.defaultValue),
                    minValue: Double(param.min),
                    maxValue: Double(param.max),
                    target: self,
                    action: #selector(parameterChanged(_:))
                )
                slider.frame = NSRect(x: margin + 90, y: y + 6, width: sliderWidth, height: 20)
                slider.tag = i
                slider.controlSize = .small
                paramPanel.addSubview(slider)
                parameterViews.append(slider)
                
                // Set initial parameter value
                previewView.setParameterValue(param.defaultValue, at: i)
            }
        }
    }
    
    @objc func templateSelected(_ sender: NSPopUpButton) {
        selectTemplate(at: sender.indexOfSelectedItem)
    }
    
    @objc func parameterChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        previewView.setParameterValue(value, at: sender.tag)
        
        if let valueLabel = window.contentView?.viewWithTag(1000 + sender.tag) as? NSTextField {
            valueLabel.stringValue = String(format: "%.2f", value)
        }
    }
    
    @objc func compileShader() {
        let source = editorView.string
        
        if previewView.loadShader(source) {
            statusLabel.stringValue = "✅ Compiled successfully"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.stringValue = "❌ \(previewView.lastError ?? "Compilation failed")"
            statusLabel.textColor = .systemRed
        }
    }
    
    @objc func saveShader() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "shader.metal"
        panel.allowedFileTypes = ["metal"]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? self.editorView.string.write(to: url, atomically: true, encoding: .utf8)
                self.statusLabel.stringValue = "Saved: \(url.lastPathComponent)"
            }
        }
    }
    
    @objc func loadShader() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["metal"]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let content = try? String(contentsOf: url) {
                    self.editorView.string = content
                    self.compileShader()
                }
            }
        }
    }
    
    @objc func exportCode() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MetalShader.swift"
        panel.allowedFileTypes = ["swift"]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let code = self.generateSwiftCode()
                try? code.write(to: url, atomically: true, encoding: .utf8)
                self.statusLabel.stringValue = "✅ Exported Swift code"
                self.statusLabel.textColor = .systemGreen
            }
        }
    }
    
    func generateSwiftCode() -> String {
        return """
import Metal
import MetalKit
import simd

class MetalShaderRenderer {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    
    struct Uniforms {
        var time: Float = 0
        var resolution: SIMD2<Float> = SIMD2<Float>(800, 600)
        var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
        var param1: Float = 0.5
        var param2: Float = 0.5
        var param3: Float = 0.5
        var param4: Float = 0.5
        var param5: Float = 0.5
        var param6: Float = 0.5
        var param7: Float = 0.5
        var param8: Float = 0.5
    }
    
    private let shaderSource = \"\"\"
\(editorView.string)
\"\"\"
    
    init() throws {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        let library = try device.makeLibrary(source: shaderSource, options: nil)
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func render(to view: MTKView, uniforms: Uniforms) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        
        var uniformData = uniforms
        encoder.setFragmentBytes(&uniformData, length: MemoryLayout<Uniforms>.size, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
"""
    }
    
    func textDidChange(_ notification: Notification) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(compileShader), object: nil)
        perform(#selector(compileShader), with: nil, afterDelay: 0.5)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        MCPServerManager.shared.stopServer()
        return true
    }
}

// MARK: - Extensions

extension NSColor {
    static var headerColor: NSColor {
        if #available(macOS 10.14, *) {
            return .controlAccentColor.withAlphaComponent(0.1)
        } else {
            return NSColor(calibratedRed: 0.0, green: 0.5, blue: 1.0, alpha: 0.1)
        }
    }
    
    static var headerTextColor: NSColor {
        if #available(macOS 10.14, *) {
            return .controlAccentColor
        } else {
            return NSColor(calibratedRed: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        }
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()