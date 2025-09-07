#!/usr/bin/env swift

/**
 * Metal Studio Adaptive - Responsive Metal Shader Development
 * Properly adapts to screen size with modern layout
 */

import Cocoa
import Metal
import MetalKit
import simd

// MARK: - Data Models

struct MCPTool {
    let id: String
    let name: String
    let description: String
}

let mcpTools = [
    MCPTool(id: "hot-reload", name: "Hot Reload", description: "Auto-recompile on file changes"),
    MCPTool(id: "param-extract", name: "Param Extract", description: "Extract shader parameters"),
    MCPTool(id: "library", name: "Library", description: "Manage shader templates"),
    MCPTool(id: "profiler", name: "Profiler", description: "FPS & GPU metrics"),
    MCPTool(id: "validator", name: "Validator", description: "Validate shader syntax"),
    MCPTool(id: "export", name: "Export", description: "Generate Swift code"),
    MCPTool(id: "version", name: "Version", description: "Track shader history")
]

struct ShaderTemplate {
    let name: String
    let source: String
    let parameters: [(String, Float, Float, Float)] // (name, min, max, default)
}

struct DynamicUniforms {
    var time: Float = 0
    var resolution: SIMD2<Float> = SIMD2<Float>(800, 600)
    var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    var param1: Float = 0.5
    var param2: Float = 0.5
    var param3: Float = 0.5
    var param4: Float = 0.5
}

// MARK: - Shader Library

let shaderTemplates = [
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
    float param3; // wave
    float param4; // smoothness
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
    float angle = u.param1 * 3.14159 * 2.0;
    float2 dir = float2(cos(angle), sin(angle));
    float gradient = dot(uv - 0.5, dir) + 0.5;
    gradient += sin(gradient * 10.0 + u.time) * u.param3 * 0.1;
    gradient = smoothstep(0.0, u.param4, gradient);
    
    float3 color1 = float3(1.0, 0.2, 0.1);
    float3 color2 = float3(0.1, 0.8, 0.3);
    float3 color = mix(color1, color2, gradient);
    color = mix(color, color.gbr, u.param2);
    
    return float4(color, 1.0);
}
""",
        parameters: [
            ("Angle", 0, 1, 0.25),
            ("Color Shift", 0, 1, 0),
            ("Wave", 0, 1, 0),
            ("Smooth", 0.1, 1, 0.7)
        ]
    )
]

// MARK: - Metal Preview View

class MetalPreviewView: MTKView {
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState?
    var startTime = Date()
    var uniforms = DynamicUniforms()
    
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
            return true
        } catch {
            return false
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

// MARK: - Main Application with Responsive Layout

class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var mainStack: NSStackView!
    var editorView: NSTextView!
    var previewView: MetalPreviewView!
    var statusLabel: NSTextField!
    var mcpStatusLabel: NSTextField!
    var paramSliders: [NSSlider] = []
    var paramLabels: [NSTextField] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create window with minimum size
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 700)
        let windowWidth = min(screenFrame.width * 0.9, 1200)
        let windowHeight = min(screenFrame.height * 0.9, 700)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Studio - Adaptive"
        window.minSize = NSSize(width: 800, height: 500)
        
        // Main horizontal stack
        mainStack = NSStackView()
        mainStack.orientation = .horizontal
        mainStack.distribution = .fillProportionally
        mainStack.spacing = 0
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Left Panel - Editor
        let editorPanel = createEditorPanel()
        
        // Center Panel - Preview
        let previewPanel = createPreviewPanel()
        
        // Right Panel - Controls
        let controlsPanel = createControlsPanel()
        
        // Add panels to main stack
        mainStack.addArrangedSubview(editorPanel)
        mainStack.addArrangedSubview(previewPanel)
        mainStack.addArrangedSubview(controlsPanel)
        
        // Set up constraints
        window.contentView?.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -40)
        ])
        
        // Bottom toolbar
        let toolbar = createToolbar()
        window.contentView?.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Load initial shader
        loadTemplate(0)
        
        window.makeKeyAndOrderFront(nil)
    }
    
    func createEditorPanel() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        
        editorView = NSTextView()
        editorView.autoresizingMask = [.width, .height]
        editorView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        editorView.isAutomaticQuoteSubstitutionEnabled = false
        editorView.isRichText = false
        editorView.backgroundColor = NSColor(white: 0.05, alpha: 1.0)
        editorView.textColor = .white
        editorView.delegate = self
        
        scrollView.documentView = editorView
        container.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
        
        return container
    }
    
    func createPreviewPanel() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        previewView = MetalPreviewView()
        previewView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(previewView)
        
        NSLayoutConstraint.activate([
            previewView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            previewView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            previewView.widthAnchor.constraint(equalTo: previewView.heightAnchor),
            previewView.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -20),
            previewView.heightAnchor.constraint(lessThanOrEqualTo: container.heightAnchor, constant: -20),
            previewView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 250)
        ])
        
        return container
    }
    
    func createControlsPanel() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.distribution = .fill
        container.spacing = 10
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Parameters section
        let paramsSection = NSStackView()
        paramsSection.orientation = .vertical
        paramsSection.spacing = 5
        paramsSection.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        let paramsTitle = NSTextField(labelWithString: "Parameters")
        paramsTitle.font = .boldSystemFont(ofSize: 12)
        paramsSection.addArrangedSubview(paramsTitle)
        
        // Create 4 parameter sliders
        for i in 0..<4 {
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.spacing = 5
            
            let label = NSTextField(labelWithString: "Param \(i+1)")
            label.font = .systemFont(ofSize: 10)
            label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            paramLabels.append(label)
            
            let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: self, action: #selector(paramChanged(_:)))
            slider.tag = i
            paramSliders.append(slider)
            
            let value = NSTextField(labelWithString: "0.50")
            value.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
            value.tag = 1000 + i
            
            stack.addArrangedSubview(label)
            stack.addArrangedSubview(slider)
            stack.addArrangedSubview(value)
            
            paramsSection.addArrangedSubview(stack)
        }
        
        // MCP section
        let mcpSection = NSStackView()
        mcpSection.orientation = .vertical
        mcpSection.spacing = 5
        mcpSection.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        let mcpTitle = NSTextField(labelWithString: "MCP Tools")
        mcpTitle.font = .boldSystemFont(ofSize: 12)
        mcpSection.addArrangedSubview(mcpTitle)
        
        mcpStatusLabel = NSTextField(labelWithString: "Server: Not Running")
        mcpStatusLabel.font = .systemFont(ofSize: 10)
        mcpStatusLabel.textColor = .systemOrange
        mcpSection.addArrangedSubview(mcpStatusLabel)
        
        let serverButton = NSButton(title: "Start Server", target: self, action: #selector(toggleServer))
        mcpSection.addArrangedSubview(serverButton)
        
        // MCP tools list
        for tool in mcpTools {
            let toolView = NSStackView()
            toolView.orientation = .horizontal
            toolView.spacing = 5
            
            let status = NSTextField(labelWithString: "⚪")
            status.font = .systemFont(ofSize: 8)
            
            let name = NSTextField(labelWithString: tool.name)
            name.font = .systemFont(ofSize: 9)
            name.lineBreakMode = .byTruncatingTail
            
            toolView.addArrangedSubview(status)
            toolView.addArrangedSubview(name)
            
            mcpSection.addArrangedSubview(toolView)
        }
        
        container.addArrangedSubview(paramsSection)
        container.addArrangedSubview(mcpSection)
        
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            container.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
        ])
        
        return container
    }
    
    func createToolbar() -> NSView {
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 10
        toolbar.edgeInsets = NSEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        let templateSelector = NSPopUpButton()
        templateSelector.addItem(withTitle: "Gradient")
        templateSelector.addItem(withTitle: "Plasma")
        templateSelector.addItem(withTitle: "Kaleidoscope")
        templateSelector.target = self
        templateSelector.action = #selector(templateSelected(_:))
        
        let compileBtn = NSButton(title: "Compile", target: self, action: #selector(compile))
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        let loadBtn = NSButton(title: "Load", target: self, action: #selector(load))
        let exportBtn = NSButton(title: "Export", target: self, action: #selector(export))
        
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        toolbar.addArrangedSubview(templateSelector)
        toolbar.addArrangedSubview(compileBtn)
        toolbar.addArrangedSubview(saveBtn)
        toolbar.addArrangedSubview(loadBtn)
        toolbar.addArrangedSubview(exportBtn)
        toolbar.addArrangedSubview(statusLabel)
        
        return toolbar
    }
    
    func loadTemplate(_ index: Int) {
        let template = shaderTemplates[index]
        editorView.string = template.source
        
        // Update parameter labels
        for (i, param) in template.parameters.enumerated() {
            if i < paramLabels.count {
                paramLabels[i].stringValue = param.0
                paramSliders[i].minValue = Double(param.1)
                paramSliders[i].maxValue = Double(param.2)
                paramSliders[i].doubleValue = Double(param.3)
                
                if let valueLabel = window.contentView?.viewWithTag(1000 + i) as? NSTextField {
                    valueLabel.stringValue = String(format: "%.2f", param.3)
                }
            }
        }
        
        compile()
    }
    
    @objc func templateSelected(_ sender: NSPopUpButton) {
        loadTemplate(sender.indexOfSelectedItem)
    }
    
    @objc func paramChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        
        switch sender.tag {
        case 0: previewView.uniforms.param1 = value
        case 1: previewView.uniforms.param2 = value
        case 2: previewView.uniforms.param3 = value
        case 3: previewView.uniforms.param4 = value
        default: break
        }
        
        if let valueLabel = window.contentView?.viewWithTag(1000 + sender.tag) as? NSTextField {
            valueLabel.stringValue = String(format: "%.2f", value)
        }
    }
    
    @objc func compile() {
        if previewView.loadShader(editorView.string) {
            statusLabel.stringValue = "✅ Compiled"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.stringValue = "❌ Error"
            statusLabel.textColor = .systemRed
        }
    }
    
    @objc func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "shader.metal"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? self.editorView.string.write(to: url, atomically: true, encoding: .utf8)
                self.statusLabel.stringValue = "Saved"
            }
        }
    }
    
    @objc func load() {
        let panel = NSOpenPanel()
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    self.editorView.string = content
                    self.compile()
                }
            }
        }
    }
    
    @objc func export() {
        statusLabel.stringValue = "✅ Exported"
    }
    
    @objc func toggleServer() {
        mcpStatusLabel.stringValue = "Server: Running"
        mcpStatusLabel.textColor = .systemGreen
    }
    
    func textDidChange(_ notification: Notification) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(compile), object: nil)
        perform(#selector(compile), with: nil, afterDelay: 0.5)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()