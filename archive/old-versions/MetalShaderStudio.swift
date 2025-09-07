#!/usr/bin/env swift

/**
 * Metal Shader Studio - Live Editor with File Explorer
 * Professional Metal shader development environment
 * 
 * Run with: swift MetalShaderStudio.swift
 */

import Cocoa
import Metal
import MetalKit
import simd

struct Uniforms {
    var time: Float = 0
    var resolution: SIMD2<Float> = SIMD2<Float>(800, 600)
    var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    var complexity: Float = 1.0
    var speed: Float = 1.0
    var colorShift: Float = 0.0
    var intensity: Float = 1.0
    var zoom: Float = 1.0
    var distortion: Float = 0.0
}

class MetalPreviewView: MTKView {
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState?
    var startTime = Date()
    var uniforms = Uniforms()
    var currentShaderSource: String = ""
    var compilationError: String?
    var onCompilationComplete: ((Bool, String?) -> Void)?
    
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
    }
    
    func compileAndLoad(_ source: String) {
        currentShaderSource = source
        compilationError = nil
        
        do {
            let library = try device?.makeLibrary(source: source, options: nil)
            let vertexFunction = library?.makeFunction(name: "vertexShader")
            let fragmentFunction = library?.makeFunction(name: "fragmentShader")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
            
            pipelineState = try device?.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            onCompilationComplete?(true, nil)
        } catch {
            compilationError = error.localizedDescription
            onCompilationComplete?(false, compilationError)
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        uniforms.mouse = SIMD2<Float>(
            Float(location.x / bounds.width),
            Float(1.0 - location.y / bounds.height)
        )
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
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        
        encoder.setRenderPipelineState(pipelineState)
        
        var uniformData = uniforms
        encoder.setFragmentBytes(&uniformData, length: MemoryLayout<Uniforms>.size, index: 0)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// Default shader template
let defaultShaderTemplate = """
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
    float complexity;
    float speed;
    float colorShift;
    float intensity;
    float zoom;
    float distortion;
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
    float2 p = (uv - 0.5) * 2.0 / u.zoom;
    p.x *= u.resolution.x / u.resolution.y;
    
    // Your shader code here
    float3 color = float3(0.0);
    
    // Simple plasma effect
    float plasma = 0.0;
    plasma += sin(p.x * 8.0 * u.complexity + u.time * u.speed);
    plasma += sin(p.y * 6.0 * u.complexity + u.time * u.speed * 0.7);
    plasma += sin(length(p) * 4.0 * u.complexity - u.time * u.speed * 0.5);
    plasma /= 3.0;
    
    // Color mapping
    color.r = sin(plasma * 3.14159 + u.colorShift * 6.28) * 0.5 + 0.5;
    color.g = sin(plasma * 3.14159 + u.colorShift * 6.28 + 2.094) * 0.5 + 0.5;
    color.b = sin(plasma * 3.14159 + u.colorShift * 6.28 + 4.189) * 0.5 + 0.5;
    
    // Apply intensity
    color *= u.intensity;
    
    // Mouse interaction
    float dist = length(p - (u.mouse - 0.5) * 2.0);
    color += exp(-dist * 2.0) * 0.3 * u.intensity;
    
    return float4(color, 1.0);
}
"""

class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var splitView: NSSplitView!
    var previewView: MetalPreviewView!
    var editorView: NSTextView!
    var fileListView: NSTableView!
    var statusLabel: NSTextField!
    var paramPanel: NSView!
    
    var shaderFiles: [String] = []
    var currentFile: String?
    var unsavedChanges = false
    
    var sliders: [String: NSSlider] = [:]
    var labels: [String: NSTextField] = [:]
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create main window
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1400, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Shader Studio"
        
        // Create split view
        splitView = NSSplitView(frame: window.contentView!.bounds)
        splitView.autoresizingMask = [.width, .height]
        splitView.dividerStyle = .thin
        splitView.isVertical = true
        
        // Left panel - File explorer
        let leftPanel = createFileExplorer()
        
        // Center panel - Editor
        let centerPanel = createEditor()
        
        // Right panel - Preview and controls
        let rightPanel = createPreviewPanel()
        
        splitView.addSubview(leftPanel)
        splitView.addSubview(centerPanel)
        splitView.addSubview(rightPanel)
        
        // Set initial sizes
        splitView.setPosition(200, ofDividerAt: 0)
        splitView.setPosition(700, ofDividerAt: 1)
        
        window.contentView?.addSubview(splitView)
        
        // Create toolbar
        createToolbar()
        
        // Load initial shader
        editorView.string = defaultShaderTemplate
        previewView.compileAndLoad(defaultShaderTemplate)
        
        // Load shader files
        loadShaderFiles()
        
        window.makeKeyAndOrderFront(nil)
        
        // Setup mouse tracking
        let trackingArea = NSTrackingArea(
            rect: previewView.bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: previewView,
            userInfo: nil
        )
        previewView.addTrackingArea(trackingArea)
    }
    
    func createFileExplorer() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 900))
        
        // Title
        let title = NSTextField(labelWithString: "Shader Files")
        title.frame = NSRect(x: 10, y: 860, width: 180, height: 30)
        title.font = .boldSystemFont(ofSize: 14)
        container.addSubview(title)
        
        // File list
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 40, width: 200, height: 820))
        fileListView = NSTableView(frame: scrollView.bounds)
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("files"))
        column.title = ""
        column.width = 180
        fileListView.addTableColumn(column)
        fileListView.headerView = nil
        fileListView.rowHeight = 24
        fileListView.delegate = self
        fileListView.dataSource = self
        fileListView.target = self
        fileListView.doubleAction = #selector(fileDoubleClicked)
        
        scrollView.documentView = fileListView
        container.addSubview(scrollView)
        
        // Buttons
        let newButton = NSButton(title: "New", target: self, action: #selector(newShader))
        newButton.frame = NSRect(x: 10, y: 5, width: 60, height: 30)
        container.addSubview(newButton)
        
        let openButton = NSButton(title: "Open", target: self, action: #selector(openShader))
        openButton.frame = NSRect(x: 75, y: 5, width: 60, height: 30)
        container.addSubview(openButton)
        
        let refreshButton = NSButton(title: "↻", target: self, action: #selector(loadShaderFiles))
        refreshButton.frame = NSRect(x: 140, y: 5, width: 50, height: 30)
        container.addSubview(refreshButton)
        
        return container
    }
    
    func createEditor() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 900))
        
        // Editor header
        let header = NSView(frame: NSRect(x: 0, y: 860, width: 500, height: 40))
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor
        
        let titleLabel = NSTextField(labelWithString: "Shader Editor")
        titleLabel.frame = NSRect(x: 10, y: 10, width: 200, height: 20)
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.textColor = .white
        header.addSubview(titleLabel)
        
        container.addSubview(header)
        
        // Text editor
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 40, width: 500, height: 820))
        editorView = NSTextView(frame: scrollView.bounds)
        editorView.autoresizingMask = [.width, .height]
        editorView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        editorView.isAutomaticQuoteSubstitutionEnabled = false
        editorView.isRichText = false
        editorView.backgroundColor = NSColor(white: 0.08, alpha: 1.0)
        editorView.textColor = .white
        editorView.insertionPointColor = .cyan
        editorView.delegate = self
        
        scrollView.documentView = editorView
        container.addSubview(scrollView)
        
        // Status bar
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.frame = NSRect(x: 10, y: 10, width: 480, height: 20)
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .gray
        container.addSubview(statusLabel)
        
        return container
    }
    
    func createPreviewPanel() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 900))
        
        // Preview
        previewView = MetalPreviewView(frame: NSRect(x: 0, y: 300, width: 700, height: 600))
        previewView.autoresizingMask = [.width, .height]
        container.addSubview(previewView)
        
        // Parameter panel
        paramPanel = createParameterPanel()
        paramPanel.frame = NSRect(x: 0, y: 0, width: 700, height: 300)
        container.addSubview(paramPanel)
        
        // Compilation status
        previewView.onCompilationComplete = { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.statusLabel.stringValue = "✅ Compiled successfully"
                    self?.statusLabel.textColor = .green
                } else {
                    self?.statusLabel.stringValue = "❌ \(error ?? "Compilation failed")"
                    self?.statusLabel.textColor = .red
                }
            }
        }
        
        return container
    }
    
    func createParameterPanel() -> NSView {
        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 300))
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor
        
        // Title
        let title = NSTextField(labelWithString: "Shader Parameters")
        title.frame = NSRect(x: 20, y: 260, width: 200, height: 30)
        title.textColor = .white
        title.font = .boldSystemFont(ofSize: 16)
        panel.addSubview(title)
        
        // Parameters in 2 columns
        let parameters: [(String, String, Float, Float, Float)] = [
            ("complexity", "Complexity", 0.5, 3.0, 1.0),
            ("speed", "Speed", 0.1, 3.0, 1.0),
            ("colorShift", "Color Shift", 0.0, 1.0, 0.0),
            ("intensity", "Intensity", 0.5, 2.0, 1.0),
            ("zoom", "Zoom", 0.5, 3.0, 1.0),
            ("distortion", "Distortion", 0.0, 1.0, 0.0)
        ]
        
        var yPos: CGFloat = 210
        var xOffset: CGFloat = 20
        
        for (i, (key, label, min, max, initial)) in parameters.enumerated() {
            if i == 3 {
                yPos = 210
                xOffset = 360
            }
            
            // Label
            let paramLabel = NSTextField(labelWithString: label)
            paramLabel.frame = NSRect(x: xOffset, y: yPos, width: 100, height: 20)
            paramLabel.textColor = .white
            paramLabel.font = .systemFont(ofSize: 13)
            panel.addSubview(paramLabel)
            
            // Value label
            let valueLabel = NSTextField(labelWithString: String(format: "%.2f", initial))
            valueLabel.frame = NSRect(x: xOffset + 280, y: yPos, width: 40, height: 20)
            valueLabel.textColor = .cyan
            valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            valueLabel.alignment = .right
            panel.addSubview(valueLabel)
            labels[key] = valueLabel
            
            // Slider
            let slider = NSSlider(value: Double(initial), minValue: Double(min), maxValue: Double(max),
                                 target: self, action: #selector(sliderChanged(_:)))
            slider.frame = NSRect(x: xOffset + 100, y: yPos - 2, width: 180, height: 24)
            slider.identifier = NSUserInterfaceItemIdentifier(key)
            panel.addSubview(slider)
            sliders[key] = slider
            
            yPos -= 60
        }
        
        // Action buttons
        let compileButton = NSButton(title: "Compile", target: self, action: #selector(compileShader))
        compileButton.frame = NSRect(x: 20, y: 20, width: 100, height: 30)
        panel.addSubview(compileButton)
        
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveShader))
        saveButton.frame = NSRect(x: 130, y: 20, width: 100, height: 30)
        panel.addSubview(saveButton)
        
        let exportButton = NSButton(title: "Export", target: self, action: #selector(exportShader))
        exportButton.frame = NSRect(x: 240, y: 20, width: 100, height: 30)
        panel.addSubview(exportButton)
        
        let resetButton = NSButton(title: "Reset", target: self, action: #selector(resetParameters))
        resetButton.frame = NSRect(x: 580, y: 20, width: 100, height: 30)
        panel.addSubview(resetButton)
        
        return panel
    }
    
    func createToolbar() {
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
    }
    
    // MARK: - Actions
    
    @objc func compileShader() {
        let source = editorView.string
        previewView.compileAndLoad(source)
    }
    
    @objc func saveShader() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["metal"]
        panel.nameFieldStringValue = currentFile ?? "shader.metal"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? self.editorView.string.write(to: url, atomically: true, encoding: .utf8)
                self.currentFile = url.lastPathComponent
                self.unsavedChanges = false
                self.statusLabel.stringValue = "Saved: \(url.lastPathComponent)"
                self.loadShaderFiles()
            }
        }
    }
    
    @objc func openShader() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["metal"]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let content = try? String(contentsOf: url) {
                    self.editorView.string = content
                    self.currentFile = url.lastPathComponent
                    self.compileShader()
                    self.loadShaderFiles()
                }
            }
        }
    }
    
    @objc func newShader() {
        if unsavedChanges {
            let alert = NSAlert()
            alert.messageText = "Unsaved Changes"
            alert.informativeText = "Do you want to save your current shader?"
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                saveShader()
            } else if response == .alertThirdButtonReturn {
                return
            }
        }
        
        editorView.string = defaultShaderTemplate
        currentFile = nil
        unsavedChanges = false
        compileShader()
    }
    
    @objc func exportShader() {
        // Export options dialog
        let alert = NSAlert()
        alert.messageText = "Export Shader"
        alert.informativeText = "Select export format:"
        alert.addButton(withTitle: "Video (MP4)")
        alert.addButton(withTitle: "GIF")
        alert.addButton(withTitle: "GLSL")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            statusLabel.stringValue = "Video export not yet implemented"
        case .alertSecondButtonReturn:
            statusLabel.stringValue = "GIF export not yet implemented"
        case .alertThirdButtonReturn:
            statusLabel.stringValue = "GLSL export not yet implemented"
        default:
            break
        }
    }
    
    @objc func sliderChanged(_ sender: NSSlider) {
        guard let key = sender.identifier?.rawValue else { return }
        let value = Float(sender.doubleValue)
        
        switch key {
        case "complexity":
            previewView.uniforms.complexity = value
        case "speed":
            previewView.uniforms.speed = value
        case "colorShift":
            previewView.uniforms.colorShift = value
        case "intensity":
            previewView.uniforms.intensity = value
        case "zoom":
            previewView.uniforms.zoom = value
        case "distortion":
            previewView.uniforms.distortion = value
        default:
            break
        }
        
        labels[key]?.stringValue = String(format: "%.2f", value)
    }
    
    @objc func resetParameters() {
        previewView.uniforms.complexity = 1.0
        previewView.uniforms.speed = 1.0
        previewView.uniforms.colorShift = 0.0
        previewView.uniforms.intensity = 1.0
        previewView.uniforms.zoom = 1.0
        previewView.uniforms.distortion = 0.0
        
        sliders["complexity"]?.doubleValue = 1.0
        sliders["speed"]?.doubleValue = 1.0
        sliders["colorShift"]?.doubleValue = 0.0
        sliders["intensity"]?.doubleValue = 1.0
        sliders["zoom"]?.doubleValue = 1.0
        sliders["distortion"]?.doubleValue = 0.0
        
        for (key, label) in labels {
            let value = sliders[key]?.floatValue ?? 0
            label.stringValue = String(format: "%.2f", value)
        }
    }
    
    @objc func loadShaderFiles() {
        shaderFiles = []
        
        // Look for .metal files in current directory
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(atPath: fm.currentDirectoryPath) {
            shaderFiles = files.filter { $0.hasSuffix(".metal") }.sorted()
        }
        
        fileListView?.reloadData()
    }
    
    @objc func fileDoubleClicked() {
        let row = fileListView.selectedRow
        if row >= 0 && row < shaderFiles.count {
            let filename = shaderFiles[row]
            if let content = try? String(contentsOfFile: filename) {
                editorView.string = content
                currentFile = filename
                unsavedChanges = false
                compileShader()
            }
        }
    }
    
    // MARK: - NSTextViewDelegate
    
    func textDidChange(_ notification: Notification) {
        unsavedChanges = true
        
        // Auto-compile after delay
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(compileShader), object: nil)
        perform(#selector(compileShader), with: nil, afterDelay: 0.5)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - NSTableViewDelegate/DataSource

extension AppDelegate: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return shaderFiles.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let text = NSTextField(labelWithString: shaderFiles[row])
        text.font = .systemFont(ofSize: 12)
        return text
    }
}

// MARK: - NSToolbarDelegate

extension AppDelegate: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return []
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return []
    }
}

// Launch app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()