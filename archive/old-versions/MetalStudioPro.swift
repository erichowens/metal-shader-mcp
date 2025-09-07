#!/usr/bin/env swift

/**
 * Metal Studio Pro - Professional Metal Shader Development
 * Fixed layout with proper panels and controls
 */

import Cocoa
import Metal
import MetalKit
import simd

// MARK: - Shader Templates

struct ShaderTemplate {
    let name: String
    let category: String
    let source: String
    let description: String
}

struct Uniforms {
    var time: Float = 0
    var resolution: SIMD2<Float> = SIMD2<Float>(800, 600)
    var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    var intensity: Float = 1.0
    var progress: Float = 0.5
    var scale: Float = 1.0
}

// MARK: - Metal Preview View

class MetalPreviewView: MTKView {
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState?
    var startTime = Date()
    var uniforms = Uniforms()
    var lastError: String?
    var currentFPS: Double = 0
    
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
        
        clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1)
        colorPixelFormat = .bgra8Unorm
        
        // Set explicit drawable size
        drawableSize = CGSize(width: 600, height: 400)
        
        delegate = self
        isPaused = false
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 60
        
        // Load default shader
        loadDefaultShader()
    }
    
    func loadDefaultShader() {
        let defaultSource = """
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
            float intensity;
            float progress;
            float scale;
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
            
            // Animated gradient
            float t = u.time + u.progress;
            float r = sin(p.x * 5.0 * u.scale + t) * 0.5 + 0.5;
            float g = sin(p.y * 5.0 * u.scale - t * 0.7) * 0.5 + 0.5;
            float b = sin(length(p) * 3.0 * u.scale + t * 0.5) * 0.5 + 0.5;
            
            float3 color = float3(r, g, b) * u.intensity;
            
            // Mouse interaction
            float dist = length(p - (u.mouse - 0.5) * 2.0);
            color += exp(-dist * 3.0) * 0.3;
            
            return float4(color, 1.0);
        }
        """
        
        _ = loadShader(defaultSource)
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

// MARK: - MTKViewDelegate

extension MetalPreviewView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
    }
    
    func draw(in view: MTKView) {
        guard let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              let pipelineState = pipelineState else { return }
        
        uniforms.time = Float(Date().timeIntervalSince(startTime))
        
        // Calculate FPS
        currentFPS = 1.0 / (CACurrentMediaTime() - (view.layer?.presentation()?.timeOffset ?? 0))
        
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

// MARK: - Main App

class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var editorView: NSTextView!
    var previewView: MetalPreviewView!
    var statusLabel: NSTextField!
    var fpsLabel: NSTextField!
    
    // Parameter controls
    var intensitySlider: NSSlider!
    var progressSlider: NSSlider!
    var scaleSlider: NSSlider!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create main window
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1200, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Studio Pro"
        
        setupUI()
        
        window.makeKeyAndOrderFront(nil)
    }
    
    func setupUI() {
        let contentView = window.contentView!
        
        // LEFT SIDE - Editor (600x700)
        setupEditor(in: contentView)
        
        // RIGHT SIDE - Preview and Controls (600x700)
        setupPreviewAndControls(in: contentView)
        
        // BOTTOM - Status and buttons
        setupBottomControls(in: contentView)
    }
    
    func setupEditor(in parent: NSView) {
        // Editor title
        let editorTitle = NSTextField(labelWithString: "Shader Code")
        editorTitle.frame = NSRect(x: 10, y: 670, width: 100, height: 20)
        editorTitle.font = .boldSystemFont(ofSize: 12)
        parent.addSubview(editorTitle)
        
        // Template selector
        let templatePopup = NSPopUpButton(frame: NSRect(x: 120, y: 665, width: 200, height: 25))
        templatePopup.addItem(withTitle: "Basic Gradient")
        templatePopup.addItem(withTitle: "Plasma Effect")
        templatePopup.addItem(withTitle: "Kaleidoscope")
        templatePopup.addItem(withTitle: "Water Ripple")
        templatePopup.addItem(withTitle: "Color Correction")
        templatePopup.target = self
        templatePopup.action = #selector(templateSelected)
        parent.addSubview(templatePopup)
        
        // Code editor
        let scrollView = NSScrollView(frame: NSRect(x: 10, y: 50, width: 580, height: 610))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        
        editorView = NSTextView(frame: scrollView.bounds)
        editorView.autoresizingMask = [.width, .height]
        editorView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        editorView.isAutomaticQuoteSubstitutionEnabled = false
        editorView.isRichText = false
        editorView.backgroundColor = NSColor(white: 0.05, alpha: 1.0)
        editorView.textColor = NSColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1.0)
        editorView.insertionPointColor = .cyan
        editorView.delegate = self
        
        scrollView.documentView = editorView
        parent.addSubview(scrollView)
    }
    
    func setupPreviewAndControls(in parent: NSView) {
        // Preview title
        let previewTitle = NSTextField(labelWithString: "Preview")
        previewTitle.frame = NSRect(x: 610, y: 670, width: 100, height: 20)
        previewTitle.font = .boldSystemFont(ofSize: 12)
        parent.addSubview(previewTitle)
        
        // FPS label
        fpsLabel = NSTextField(labelWithString: "FPS: 0")
        fpsLabel.frame = NSRect(x: 1100, y: 670, width: 80, height: 20)
        fpsLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        fpsLabel.textColor = .green
        fpsLabel.alignment = .right
        parent.addSubview(fpsLabel)
        
        // Metal preview
        previewView = MetalPreviewView(frame: NSRect(x: 610, y: 250, width: 580, height: 410))
        previewView.layer?.borderColor = NSColor.darkGray.cgColor
        previewView.layer?.borderWidth = 1
        parent.addSubview(previewView)
        
        // Parameter controls
        setupParameterControls(in: parent)
        
        // Track mouse in preview
        let trackingArea = NSTrackingArea(
            rect: previewView.bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: previewView,
            userInfo: nil
        )
        previewView.addTrackingArea(trackingArea)
        
        // Update FPS
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.fpsLabel.stringValue = String(format: "FPS: %.0f", self.previewView.currentFPS)
        }
    }
    
    func setupParameterControls(in parent: NSView) {
        var yPos: CGFloat = 200
        
        // Intensity
        let intensityLabel = NSTextField(labelWithString: "Intensity")
        intensityLabel.frame = NSRect(x: 620, y: yPos, width: 80, height: 20)
        parent.addSubview(intensityLabel)
        
        intensitySlider = NSSlider(value: 1.0, minValue: 0, maxValue: 2,
                                   target: self, action: #selector(parameterChanged))
        intensitySlider.frame = NSRect(x: 700, y: yPos, width: 200, height: 20)
        intensitySlider.tag = 1
        parent.addSubview(intensitySlider)
        
        let intensityValue = NSTextField(labelWithString: "1.0")
        intensityValue.frame = NSRect(x: 910, y: yPos, width: 40, height: 20)
        intensityValue.tag = 101
        parent.addSubview(intensityValue)
        
        yPos -= 40
        
        // Progress
        let progressLabel = NSTextField(labelWithString: "Progress")
        progressLabel.frame = NSRect(x: 620, y: yPos, width: 80, height: 20)
        parent.addSubview(progressLabel)
        
        progressSlider = NSSlider(value: 0.5, minValue: 0, maxValue: 1,
                                  target: self, action: #selector(parameterChanged))
        progressSlider.frame = NSRect(x: 700, y: yPos, width: 200, height: 20)
        progressSlider.tag = 2
        parent.addSubview(progressSlider)
        
        let progressValue = NSTextField(labelWithString: "0.5")
        progressValue.frame = NSRect(x: 910, y: yPos, width: 40, height: 20)
        progressValue.tag = 102
        parent.addSubview(progressValue)
        
        yPos -= 40
        
        // Scale
        let scaleLabel = NSTextField(labelWithString: "Scale")
        scaleLabel.frame = NSRect(x: 620, y: yPos, width: 80, height: 20)
        parent.addSubview(scaleLabel)
        
        scaleSlider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 5,
                               target: self, action: #selector(parameterChanged))
        scaleSlider.frame = NSRect(x: 700, y: yPos, width: 200, height: 20)
        scaleSlider.tag = 3
        parent.addSubview(scaleSlider)
        
        let scaleValue = NSTextField(labelWithString: "1.0")
        scaleValue.frame = NSRect(x: 910, y: yPos, width: 40, height: 20)
        scaleValue.tag = 103
        parent.addSubview(scaleValue)
    }
    
    func setupBottomControls(in parent: NSView) {
        // Compile button
        let compileButton = NSButton(title: "Compile", target: self, action: #selector(compileShader))
        compileButton.frame = NSRect(x: 10, y: 10, width: 100, height: 30)
        parent.addSubview(compileButton)
        
        // Save button
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveShader))
        saveButton.frame = NSRect(x: 120, y: 10, width: 100, height: 30)
        parent.addSubview(saveButton)
        
        // Load button
        let loadButton = NSButton(title: "Load", target: self, action: #selector(loadShader))
        loadButton.frame = NSRect(x: 230, y: 10, width: 100, height: 30)
        parent.addSubview(loadButton)
        
        // Export button
        let exportButton = NSButton(title: "Export", target: self, action: #selector(exportCode))
        exportButton.frame = NSRect(x: 340, y: 10, width: 100, height: 30)
        parent.addSubview(exportButton)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.frame = NSRect(x: 460, y: 15, width: 600, height: 20)
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .lightGray
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        parent.addSubview(statusLabel)
    }
    
    @objc func parameterChanged(_ sender: NSSlider) {
        let value = sender.floatValue
        
        // Update value label
        if let valueLabel = window.contentView?.viewWithTag(sender.tag + 100) as? NSTextField {
            valueLabel.stringValue = String(format: "%.2f", value)
        }
        
        // Update uniforms
        switch sender.tag {
        case 1: previewView.uniforms.intensity = value
        case 2: previewView.uniforms.progress = value
        case 3: previewView.uniforms.scale = value
        default: break
        }
    }
    
    @objc func templateSelected(_ sender: NSPopUpButton) {
        let templates = [
            getGradientShader(),
            getPlasmaShader(),
            getKaleidoscopeShader(),
            getRippleShader(),
            getColorCorrectionShader()
        ]
        
        let index = sender.indexOfSelectedItem
        if index < templates.count {
            editorView.string = templates[index]
            compileShader()
        }
    }
    
    @objc func compileShader() {
        let source = editorView.string
        
        if previewView.loadShader(source) {
            statusLabel.stringValue = "✅ Compiled successfully"
            statusLabel.textColor = .green
        } else {
            statusLabel.stringValue = "❌ \(previewView.lastError ?? "Compilation failed")"
            statusLabel.textColor = .red
        }
    }
    
    @objc func saveShader() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "shader.metal"
        panel.allowedContentTypes = [.plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? self.editorView.string.write(to: url, atomically: true, encoding: .utf8)
                self.statusLabel.stringValue = "Saved: \(url.lastPathComponent)"
                self.statusLabel.textColor = .white
            }
        }
    }
    
    @objc func loadShader() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    self.editorView.string = content
                    self.compileShader()
                    self.statusLabel.stringValue = "Loaded: \(url.lastPathComponent)"
                }
            }
        }
    }
    
    @objc func exportCode() {
        statusLabel.stringValue = "Export feature - generates Swift integration code"
        statusLabel.textColor = .systemBlue
    }
    
    // Auto-compile on text change
    func textDidChange(_ notification: Notification) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(compileShader), object: nil)
        perform(#selector(compileShader), with: nil, afterDelay: 0.5)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Shader Templates
    
    func getGradientShader() -> String {
        return """
        // Basic gradient shader - modify as needed
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
            float intensity;
            float progress;
            float scale;
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
            float gradient = uv.x * u.progress + uv.y * (1.0 - u.progress);
            float3 color = mix(float3(0.1, 0.2, 0.5), float3(0.9, 0.4, 0.1), gradient);
            return float4(color * u.intensity, 1.0);
        }
        """
    }
    
    func getPlasmaShader() -> String {
        return """
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
            float intensity;
            float progress;
            float scale;
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
            
            float plasma = 0.0;
            plasma += sin(p.x * 10.0 * u.scale + u.time);
            plasma += sin(p.y * 8.0 * u.scale - u.time * 0.5);
            plasma += sin(length(p * 5.0 * u.scale) - u.time * 2.0);
            plasma /= 3.0;
            
            float3 color;
            color.r = sin(plasma * 3.14159 + 0.0) * 0.5 + 0.5;
            color.g = sin(plasma * 3.14159 + 2.094) * 0.5 + 0.5;
            color.b = sin(plasma * 3.14159 + 4.189) * 0.5 + 0.5;
            
            return float4(color * u.intensity, 1.0);
        }
        """
    }
    
    func getKaleidoscopeShader() -> String {
        return """
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
            float intensity;
            float progress;
            float scale;
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
        
        float hash(float2 p) {
            p = fract(p * float2(123.34, 456.21));
            p += dot(p, p + 45.32);
            return fract(p.x * p.y);
        }
        
        fragment float4 fragmentShader(
            VertexOut in [[stage_in]],
            constant Uniforms& u [[buffer(0)]]
        ) {
            float2 p = (in.texCoord - 0.5) * 2.0;
            p.x *= u.resolution.x / u.resolution.y;
            
            // Kaleidoscope transformation
            float angle = atan2(p.y, p.x) + u.time * 0.5;
            float radius = length(p) * u.scale;
            
            float segments = 6.0;
            float segmentAngle = 2.0 * M_PI_F / segments;
            angle = fmod(angle, segmentAngle);
            
            if (int(atan2(p.y, p.x) / segmentAngle) % 2 == 1) {
                angle = segmentAngle - angle;
            }
            
            float2 kp = radius * float2(cos(angle), sin(angle));
            
            // Color blocks
            float2 blockUV = floor(kp * 8.0) / 8.0;
            float colorIndex = hash(blockUV + u.time * 0.1) * 4.0;
            
            float3 color;
            if (colorIndex < 1.0) {
                color = float3(1.0, 0.2, 0.2);
            } else if (colorIndex < 2.0) {
                color = float3(0.2, 1.0, 0.2);
            } else if (colorIndex < 3.0) {
                color = float3(0.2, 0.4, 1.0);
            } else {
                color = float3(1.0, 0.9, 0.2);
            }
            
            return float4(color * u.intensity, 1.0);
        }
        """
    }
    
    func getRippleShader() -> String {
        return """
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
            float intensity;
            float progress;
            float scale;
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
            float2 center = u.mouse;
            
            float dist = distance(uv, center);
            float ripple = sin(dist * 30.0 * u.scale - u.time * 5.0) * 0.5 + 0.5;
            ripple *= exp(-dist * 3.0);
            
            float3 color = float3(0.1, 0.3, 0.6);
            color = mix(color, float3(0.9, 0.95, 1.0), ripple * u.intensity);
            
            return float4(color, 1.0);
        }
        """
    }
    
    func getColorCorrectionShader() -> String {
        return """
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
            float intensity;
            float progress;
            float scale;
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
            
            // Base color from UV
            float3 color = float3(uv.x, uv.y, 0.5);
            
            // Color correction
            color = pow(color, float3(1.0 / (2.2 * u.scale))); // Gamma
            color = mix(color, color * color, u.progress); // Contrast
            color = color * u.intensity; // Brightness
            
            // Vignette
            float vignette = 1.0 - length(uv - 0.5) * 0.7;
            color *= vignette;
            
            return float4(color, 1.0);
        }
        """
    }
}

// Run the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()