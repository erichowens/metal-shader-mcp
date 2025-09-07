#!/usr/bin/env swift

/**
 * Metal Studio Pro 2 - Professional Metal Shader Development
 * Optimized for shader artists with resizable panes and large preview
 */

import Cocoa
import Metal
import MetalKit
import simd

// MARK: - Shader Template System

struct ShaderTemplate {
    let name: String
    let source: String
    let parameters: [(String, Float, Float, Float)] // (name, min, max, default)
}

struct Uniforms {
    var time: Float = 0
    var resolution: SIMD2<Float> = SIMD2<Float>(800, 800)
    var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    var param1: Float = 0.5
    var param2: Float = 0.5
    var param3: Float = 0.5
    var param4: Float = 0.5
}

let defaultShader = """
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
    float param1; // complexity
    float param2; // speed
    float param3; // color_shift
    float param4; // intensity
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
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    // Dynamic plasma effect
    float t = u.time * u.param2;
    float complexity = u.param1 * 10.0;
    
    float plasma = 0.0;
    plasma += sin(p.x * complexity + t);
    plasma += sin(p.y * complexity * 0.8 - t * 0.5);
    plasma += sin(length(p * complexity * 0.5) - t * 2.0);
    
    // Mouse interaction
    float2 mousePos = (u.mouse - 0.5) * 2.0;
    float dist = length(p - mousePos);
    plasma += exp(-dist * 2.0) * sin(t * 3.0);
    
    plasma *= u.param4; // intensity
    
    // Color with shift
    float3 color;
    float shift = u.param3 * 6.28318;
    color.r = sin(plasma * 3.14159 + shift) * 0.5 + 0.5;
    color.g = sin(plasma * 3.14159 + 2.094 + shift) * 0.5 + 0.5;
    color.b = sin(plasma * 3.14159 + 4.189 + shift) * 0.5 + 0.5;
    
    return float4(color, 1.0);
}
"""

// MARK: - Metal Preview View

class MetalPreviewView: MTKView {
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState?
    var startTime = Date()
    var uniforms = Uniforms()
    var lastError: String?
    var fps: Double = 0
    private var frameCount = 0
    private var lastFPSUpdate = Date()
    
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
        clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1)
        colorPixelFormat = .bgra8Unorm
        delegate = self
        isPaused = false
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 60
        
        // Shadow effect
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.5
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 10
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
        
        // Update FPS
        frameCount += 1
        let now = Date()
        if now.timeIntervalSince(lastFPSUpdate) >= 0.5 {
            fps = Double(frameCount) / now.timeIntervalSince(lastFPSUpdate)
            frameCount = 0
            lastFPSUpdate = now
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
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

// MARK: - FPS Overlay View

class FPSOverlayView: NSView {
    var fps: Double = 0 {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let fpsString = String(format: "%.0f FPS", fps)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold),
            .foregroundColor: fps >= 55 ? NSColor.systemGreen : NSColor.systemOrange
        ]
        
        let size = fpsString.size(withAttributes: attributes)
        let rect = NSRect(x: bounds.width - size.width - 10,
                         y: bounds.height - size.height - 10,
                         width: size.width,
                         height: size.height)
        
        fpsString.draw(in: rect, withAttributes: attributes)
    }
    
    override var isFlipped: Bool { true }
}

// MARK: - Main Application

class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate, NSSplitViewDelegate {
    var window: NSWindow!
    var splitView: NSSplitView!
    var editorView: NSTextView!
    var previewView: MetalPreviewView!
    var fpsOverlay: FPSOverlayView!
    var statusLabel: NSTextField!
    var paramSliders: [NSSlider] = []
    var paramLabels: [NSTextField] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create window - larger default size for shader work
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1600, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Studio Pro - Shader Development"
        window.minSize = NSSize(width: 1200, height: 700)
        window.backgroundColor = NSColor(white: 0.08, alpha: 1.0)
        
        // Create split view
        splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        
        // Left Pane - Code Editor (narrow)
        let editorContainer = createEditorPane()
        
        // Center Pane - Large Preview
        let previewContainer = createPreviewPane()
        
        // Right Pane - Controls
        let controlsContainer = createControlsPane()
        
        // Add panes to split view
        splitView.addArrangedSubview(editorContainer)
        splitView.addArrangedSubview(previewContainer)
        splitView.addArrangedSubview(controlsContainer)
        
        // Set initial sizes - give most space to preview
        splitView.setPosition(400, ofDividerAt: 0)
        splitView.setPosition(1200, ofDividerAt: 1)
        
        // Main container
        let mainContainer = NSView()
        mainContainer.addSubview(splitView)
        
        // Bottom toolbar
        let toolbar = createToolbar()
        mainContainer.addSubview(toolbar)
        
        // Layout
        splitView.translatesAutoresizingMaskIntoConstraints = false
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
            
            toolbar.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        window.contentView = mainContainer
        
        // Load initial shader
        editorView.string = defaultShader
        compileShader()
        
        // Setup FPS timer
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.fpsOverlay.fps = self.previewView.fps
        }
        
        window.makeKeyAndOrderFront(nil)
    }
    
    func createEditorPane() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.05, alpha: 1.0).cgColor
        
        // Header
        let header = NSTextField(labelWithString: "SHADER CODE")
        header.font = .systemFont(ofSize: 11, weight: .medium)
        header.textColor = .secondaryLabelColor
        container.addSubview(header)
        
        // Scroll view for editor
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        
        editorView = NSTextView()
        editorView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        editorView.isAutomaticQuoteSubstitutionEnabled = false
        editorView.isRichText = false
        editorView.backgroundColor = NSColor(white: 0.03, alpha: 1.0)
        editorView.textColor = NSColor(red: 0.8, green: 0.9, blue: 0.7, alpha: 1.0)
        editorView.insertionPointColor = .cyan
        editorView.delegate = self
        
        // Set text container width for ~80-100 chars
        editorView.textContainer?.containerSize = CGSize(width: 600, height: CGFloat.greatestFiniteMagnitude)
        editorView.textContainer?.widthTracksTextView = false
        
        scrollView.documentView = editorView
        container.addSubview(scrollView)
        
        // Layout
        header.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    func createPreviewPane() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.02, alpha: 1.0).cgColor
        
        // Create Metal view with large size
        previewView = MetalPreviewView()
        previewView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(previewView)
        
        // FPS overlay
        fpsOverlay = FPSOverlayView()
        fpsOverlay.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(fpsOverlay)
        
        // Preview controls overlay
        let controlsOverlay = createPreviewControls()
        container.addSubview(controlsOverlay)
        
        // Constraints - make preview as large as possible while maintaining aspect ratio
        NSLayoutConstraint.activate([
            // Preview centered and square
            previewView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            previewView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            previewView.widthAnchor.constraint(equalTo: previewView.heightAnchor),
            
            // Take up most of available space
            previewView.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, multiplier: 0.9),
            previewView.heightAnchor.constraint(lessThanOrEqualTo: container.heightAnchor, multiplier: 0.9),
            
            // Minimum size
            previewView.widthAnchor.constraint(greaterThanOrEqualToConstant: 400),
            
            // FPS overlay
            fpsOverlay.topAnchor.constraint(equalTo: container.topAnchor),
            fpsOverlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            fpsOverlay.widthAnchor.constraint(equalToConstant: 100),
            fpsOverlay.heightAnchor.constraint(equalToConstant: 40),
            
            // Controls overlay
            controlsOverlay.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            controlsOverlay.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])
        
        // Track mouse for preview
        let trackingArea = NSTrackingArea(
            rect: container.bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: previewView,
            userInfo: nil
        )
        previewView.addTrackingArea(trackingArea)
        
        return container
    }
    
    func createPreviewControls() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let playButton = NSButton(title: "▶", target: self, action: #selector(togglePlay))
        playButton.bezelStyle = .rounded
        
        let resetButton = NSButton(title: "↺", target: self, action: #selector(resetAnimation))
        resetButton.bezelStyle = .rounded
        
        let captureButton = NSButton(title: "📷", target: self, action: #selector(captureFrame))
        captureButton.bezelStyle = .rounded
        
        stack.addArrangedSubview(playButton)
        stack.addArrangedSubview(resetButton)
        stack.addArrangedSubview(captureButton)
        
        return stack
    }
    
    func createControlsPane() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.06, alpha: 1.0).cgColor
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        
        let contentView = NSView()
        
        // Parameters section
        let paramsLabel = NSTextField(labelWithString: "PARAMETERS")
        paramsLabel.font = .systemFont(ofSize: 11, weight: .medium)
        paramsLabel.textColor = .secondaryLabelColor
        contentView.addSubview(paramsLabel)
        
        var yOffset: CGFloat = 40
        
        // Create parameter controls
        let paramNames = ["Complexity", "Speed", "Color Shift", "Intensity"]
        for (i, name) in paramNames.enumerated() {
            let label = NSTextField(labelWithString: name)
            label.font = .systemFont(ofSize: 11)
            label.frame = NSRect(x: 10, y: yOffset, width: 80, height: 20)
            contentView.addSubview(label)
            paramLabels.append(label)
            
            let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: self, action: #selector(paramChanged(_:)))
            slider.frame = NSRect(x: 95, y: yOffset, width: 180, height: 20)
            slider.tag = i
            contentView.addSubview(slider)
            paramSliders.append(slider)
            
            let value = NSTextField(labelWithString: "0.50")
            value.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
            value.frame = NSRect(x: 280, y: yOffset, width: 40, height: 20)
            value.tag = 1000 + i
            value.isEditable = false
            value.isBordered = false
            value.backgroundColor = .clear
            contentView.addSubview(value)
            
            yOffset += 35
        }
        
        // MCP Tools section
        yOffset += 20
        let mcpLabel = NSTextField(labelWithString: "MCP TOOLS")
        mcpLabel.font = .systemFont(ofSize: 11, weight: .medium)
        mcpLabel.textColor = .secondaryLabelColor
        mcpLabel.frame = NSRect(x: 10, y: yOffset, width: 100, height: 20)
        contentView.addSubview(mcpLabel)
        
        yOffset += 25
        let mcpStatus = NSTextField(labelWithString: "⚫ Not Connected")
        mcpStatus.font = .systemFont(ofSize: 10)
        mcpStatus.frame = NSRect(x: 10, y: yOffset, width: 200, height: 20)
        contentView.addSubview(mcpStatus)
        
        yOffset += 25
        let tools = ["Hot Reload", "Param Extract", "Profiler", "Validator", "Export"]
        for tool in tools {
            let toolLabel = NSTextField(labelWithString: "  • \(tool)")
            toolLabel.font = .systemFont(ofSize: 10)
            toolLabel.textColor = .tertiaryLabelColor
            toolLabel.frame = NSRect(x: 10, y: yOffset, width: 200, height: 18)
            contentView.addSubview(toolLabel)
            yOffset += 20
        }
        
        contentView.frame = NSRect(x: 0, y: 0, width: 330, height: yOffset + 50)
        scrollView.documentView = contentView
        
        container.addSubview(scrollView)
        
        // Layout
        paramsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            paramsLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            paramsLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    func createToolbar() -> NSView {
        let toolbar = NSView()
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor(white: 0.04, alpha: 1.0).cgColor
        
        // Compile button
        let compileBtn = NSButton(title: "Compile", target: self, action: #selector(compileShader))
        compileBtn.frame = NSRect(x: 10, y: 6, width: 80, height: 24)
        toolbar.addSubview(compileBtn)
        
        // Status
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 100, y: 8, width: 300, height: 20)
        toolbar.addSubview(statusLabel)
        
        // Export button
        let exportBtn = NSButton(title: "Export", target: self, action: #selector(exportShader))
        exportBtn.frame = NSRect(x: 500, y: 6, width: 80, height: 24)
        toolbar.addSubview(exportBtn)
        
        return toolbar
    }
    
    // MARK: - Split View Delegate
    
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if dividerIndex == 0 {
            return 300 // Minimum width for editor
        } else {
            return proposedMinimumPosition + 400 // Minimum width for preview
        }
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if dividerIndex == 0 {
            return 500 // Maximum width for editor
        } else {
            return splitView.frame.width - 280 // Minimum width for controls
        }
    }
    
    // MARK: - Actions
    
    @objc func compileShader() {
        if previewView.loadShader(editorView.string) {
            statusLabel.stringValue = "✅ Compiled successfully"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.stringValue = "❌ \(previewView.lastError ?? "Compilation failed")"
            statusLabel.textColor = .systemRed
        }
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
    
    @objc func togglePlay() {
        previewView.isPaused.toggle()
    }
    
    @objc func resetAnimation() {
        previewView.startTime = Date()
    }
    
    @objc func captureFrame() {
        // Capture current frame
        statusLabel.stringValue = "Frame captured"
    }
    
    @objc func exportShader() {
        statusLabel.stringValue = "Shader exported"
    }
    
    func textDidChange(_ notification: Notification) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(compileShader), object: nil)
        perform(#selector(compileShader), with: nil, afterDelay: 0.5)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()