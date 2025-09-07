#!/usr/bin/env swift

/**
 * Metal Studio Simple - Reliable shader editor with preview
 * Run with: swift MetalStudioSimple.swift
 */

import Cocoa
import Metal
import MetalKit
import simd

struct Uniforms {
    var time: Float = 0
    var resolution: SIMD2<Float> = SIMD2<Float>(800, 600)
    var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
}

class MetalPreviewView: MTKView {
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState?
    var startTime = Date()
    var uniforms = Uniforms()
    var lastError: String?
    
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
        
        clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        colorPixelFormat = .bgra8Unorm
        
        // Important: Set drawable size explicitly
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
    
    // Animated plasma
    float plasma = 0.0;
    plasma += sin(p.x * 10.0 + u.time);
    plasma += sin(p.y * 8.0 - u.time * 0.5);
    plasma += sin(length(p * 5.0) - u.time * 2.0);
    plasma /= 3.0;
    
    // Color gradient
    float3 color;
    color.r = sin(plasma * 3.14159 + 0.0) * 0.5 + 0.5;
    color.g = sin(plasma * 3.14159 + 2.094) * 0.5 + 0.5;
    color.b = sin(plasma * 3.14159 + 4.189) * 0.5 + 0.5;
    
    // Mouse interaction
    float dist = length(p - (u.mouse - 0.5) * 2.0);
    color += exp(-dist * 3.0) * 0.3;
    
    return float4(color, 1.0);
}
"""

class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var editorView: NSTextView!
    var previewView: MetalPreviewView!
    var statusLabel: NSTextField!
    var compileButton: NSButton!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create window
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1200, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Shader Studio - Simple"
        
        // Left side - Editor
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 40, width: 600, height: 660))
        editorView = NSTextView(frame: scrollView.bounds)
        editorView.autoresizingMask = [.width, .height]
        editorView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        editorView.isAutomaticQuoteSubstitutionEnabled = false
        editorView.isRichText = false
        editorView.backgroundColor = NSColor(white: 0.05, alpha: 1.0)
        editorView.textColor = .white
        editorView.insertionPointColor = .cyan
        editorView.string = defaultShader
        editorView.delegate = self
        
        scrollView.documentView = editorView
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(scrollView)
        
        // Right side - Preview
        previewView = MetalPreviewView(frame: NSRect(x: 600, y: 40, width: 600, height: 600))
        previewView.autoresizingMask = [.minXMargin, .height]
        window.contentView?.addSubview(previewView)
        
        // Bottom controls
        compileButton = NSButton(title: "Compile", target: self, action: #selector(compileShader))
        compileButton.frame = NSRect(x: 10, y: 5, width: 100, height: 30)
        window.contentView?.addSubview(compileButton)
        
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveShader))
        saveButton.frame = NSRect(x: 120, y: 5, width: 100, height: 30)
        window.contentView?.addSubview(saveButton)
        
        let loadButton = NSButton(title: "Load", target: self, action: #selector(loadShader))
        loadButton.frame = NSRect(x: 230, y: 5, width: 100, height: 30)
        window.contentView?.addSubview(loadButton)
        
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.frame = NSRect(x: 350, y: 10, width: 500, height: 20)
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .gray
        window.contentView?.addSubview(statusLabel)
        
        // Track mouse
        let trackingArea = NSTrackingArea(
            rect: previewView.bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: previewView,
            userInfo: nil
        )
        previewView.addTrackingArea(trackingArea)
        
        // Initial compile
        compileShader()
        
        window.makeKeyAndOrderFront(nil)
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
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    self.editorView.string = content
                    self.compileShader()
                }
            }
        }
    }
    
    // Auto-compile on text change
    func textDidChange(_ notification: Notification) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(compileShader), object: nil)
        perform(#selector(compileShader), with: nil, afterDelay: 0.5)
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