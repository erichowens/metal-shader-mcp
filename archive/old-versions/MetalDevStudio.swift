#!/usr/bin/env swift

/**
 * Metal Dev Studio - Professional Metal Shader Development Environment
 * For iOS/macOS developers building real production shaders
 * 
 * Run with: swift MetalDevStudio.swift
 */

import Cocoa
import Metal
import MetalKit
import MetalPerformanceShaders
import simd
import UniformTypeIdentifiers

// Standard uniforms for most iOS/macOS apps
struct StandardUniforms {
    var time: Float = 0
    var resolution: SIMD2<Float> = SIMD2<Float>(1920, 1080)
    var mouse: SIMD2<Float> = SIMD2<Float>(0, 0)
    // Common parameters used in production
    var intensity: Float = 1.0      // Effect strength
    var progress: Float = 0.0       // Animation/transition progress
    var scale: Float = 1.0          // Zoom/scale factor
    var rotation: Float = 0.0       // Rotation angle
    var offset: SIMD2<Float> = SIMD2<Float>(0, 0)  // Pan offset
    var color1: SIMD4<Float> = SIMD4<Float>(1, 0, 0, 1)  // Primary color
    var color2: SIMD4<Float> = SIMD4<Float>(0, 0, 1, 1)  // Secondary color
}

// Common shader templates
struct ShaderTemplate {
    let name: String
    let category: String
    let code: String
    let description: String
}

class ShaderTemplates {
    static let templates = [
        ShaderTemplate(
            name: "Gaussian Blur",
            category: "Image Filters",
            code: gaussianBlurShader,
            description: "Standard Gaussian blur for UI backgrounds"
        ),
        ShaderTemplate(
            name: "Color Correction",
            category: "Image Filters", 
            code: colorCorrectionShader,
            description: "Brightness, contrast, saturation adjustments"
        ),
        ShaderTemplate(
            name: "Ripple Effect",
            category: "UI Effects",
            code: rippleShader,
            description: "Touch ripple for buttons and interactions"
        ),
        ShaderTemplate(
            name: "Page Curl",
            category: "Transitions",
            code: pageCurlShader,
            description: "Page turning transition effect"
        ),
        ShaderTemplate(
            name: "Water Surface",
            category: "Game Shaders",
            code: waterShader,
            description: "Animated water with reflections"
        ),
        ShaderTemplate(
            name: "Particle System",
            category: "Visual Effects",
            code: particleShader,
            description: "GPU-based particle rendering"
        )
    ]
    
    // Gaussian Blur - Most requested shader for iOS apps
    static let gaussianBlurShader = """
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
    float intensity;  // Blur radius
    float progress;
    float scale;
    float rotation;
    float2 offset;
    float4 color1;
    float4 color2;
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
    texture2d<float> inputTexture [[texture(0)]],
    constant Uniforms& u [[buffer(0)]]
) {
    constexpr sampler s(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    float blurSize = u.intensity * 0.01;
    
    // 9-tap Gaussian blur
    float4 color = float4(0.0);
    float total = 0.0;
    
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            float2 offset = float2(x, y) * blurSize;
            float weight = exp(-(x*x + y*y) / 4.0);
            color += inputTexture.sample(s, uv + offset) * weight;
            total += weight;
        }
    }
    
    return color / total;
}
"""
    
    // Color Correction - Essential for photo apps
    static let colorCorrectionShader = """
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
    float intensity;  // Overall effect strength
    float progress;   // Used as brightness
    float scale;      // Used as contrast  
    float rotation;   // Used as saturation
    float2 offset;
    float4 color1;    // Tint color
    float4 color2;
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
    texture2d<float> inputTexture [[texture(0)]],
    constant Uniforms& u [[buffer(0)]]
) {
    constexpr sampler s(mag_filter::linear, min_filter::linear);
    
    float4 color = inputTexture.sample(s, in.texCoord);
    
    // Brightness
    color.rgb += u.progress - 0.5;
    
    // Contrast  
    color.rgb = (color.rgb - 0.5) * (u.scale * 2.0) + 0.5;
    
    // Saturation
    float luminance = dot(color.rgb, float3(0.299, 0.587, 0.114));
    color.rgb = mix(float3(luminance), color.rgb, u.rotation * 2.0);
    
    // Tint
    color.rgb = mix(color.rgb, color.rgb * u.color1.rgb, u.intensity);
    
    return float4(clamp(color.rgb, 0.0, 1.0), color.a);
}
"""
    
    // Ripple Effect - Common UI interaction
    static let rippleShader = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;     // Touch point
    float intensity;  // Ripple strength
    float progress;   // Animation progress
    float scale;      // Ripple frequency
    float rotation;   // Decay rate
    float2 offset;
    float4 color1;    // Ripple color
    float4 color2;
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
    texture2d<float> inputTexture [[texture(0)]],
    constant Uniforms& u [[buffer(0)]]
) {
    constexpr sampler s(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    float4 color = inputTexture.sample(s, uv);
    
    // Calculate ripple from touch point
    float dist = length(uv - u.mouse);
    float ripple = sin(dist * u.scale * 50.0 - u.progress * 10.0);
    ripple *= exp(-dist * u.rotation * 5.0);
    ripple *= exp(-u.progress * 2.0); // Fade out over time
    
    // Apply ripple distortion
    float2 offset = normalize(uv - u.mouse) * ripple * u.intensity * 0.01;
    float4 distorted = inputTexture.sample(s, uv + offset);
    
    // Add ripple color overlay
    float3 rippleColor = mix(color.rgb, u.color1.rgb, ripple * 0.5);
    
    return float4(mix(color.rgb, rippleColor, clamp(ripple, 0.0, 1.0)), color.a);
}
"""
    
    // Page Curl Transition - Popular in reader apps
    static let pageCurlShader = """
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
    float intensity;  // Curl intensity
    float progress;   // Transition progress (0-1)
    float scale;
    float rotation;
    float2 offset;
    float4 color1;    // Page background
    float4 color2;    // Shadow color
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
    texture2d<float> inputTexture [[texture(0)]],
    constant Uniforms& u [[buffer(0)]]
) {
    constexpr sampler s(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    
    // Simulate page curl from bottom-right corner
    float curl = u.progress;
    float2 curlCenter = float2(1.0 - curl, 1.0 - curl);
    
    float dist = length(uv - curlCenter);
    float curlRadius = curl * 1.414; // sqrt(2) for diagonal
    
    if (dist < curlRadius) {
        // On the curled part
        float angle = atan2(uv.y - curlCenter.y, uv.x - curlCenter.x);
        float2 flipped = curlCenter + float2(cos(angle + M_PI_F), sin(angle + M_PI_F)) * dist;
        
        // Sample the back of the page (could be different texture)
        float4 backColor = u.color1;
        
        // Add shadow
        float shadow = 1.0 - smoothstep(0.0, 0.2, dist - curlRadius + 0.2);
        backColor.rgb *= shadow;
        
        return backColor;
    } else {
        // Normal page
        return inputTexture.sample(s, uv);
    }
}
"""
    
    // Water Surface - Common game shader
    static let waterShader = """
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
    float intensity;  // Wave height
    float progress;   // Flow speed
    float scale;      // Wave frequency
    float rotation;   // Refraction strength
    float2 offset;
    float4 color1;    // Water color (deep)
    float4 color2;    // Water color (shallow)
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

// Simple noise for water waves
float noise(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant Uniforms& u [[buffer(0)]]
) {
    constexpr sampler s(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    
    // Create water waves
    float wave1 = sin(uv.x * u.scale * 10.0 + u.time * u.progress * 2.0) * u.intensity * 0.01;
    float wave2 = sin(uv.y * u.scale * 8.0 - u.time * u.progress * 1.5) * u.intensity * 0.01;
    float wave3 = sin((uv.x + uv.y) * u.scale * 12.0 + u.time * u.progress) * u.intensity * 0.005;
    
    // Combine waves
    float2 distortion = float2(wave1 + wave3, wave2 + wave3);
    
    // Sample with refraction
    float4 refracted = inputTexture.sample(s, uv + distortion * u.rotation);
    
    // Water color based on depth (simulated)
    float depth = noise(uv * 10.0 + u.time * 0.1);
    float3 waterColor = mix(u.color2.rgb, u.color1.rgb, depth);
    
    // Mix refracted scene with water color
    float3 finalColor = mix(refracted.rgb, waterColor, 0.5);
    
    // Add specular highlights
    float specular = pow(max(0.0, wave1 + wave2), 8.0) * 2.0;
    finalColor += specular;
    
    return float4(finalColor, 1.0);
}
"""
    
    // Particle System - For visual effects
    static let particleShader = """
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
    float intensity;  // Particle count multiplier
    float progress;   // Particle speed
    float scale;      // Particle size
    float rotation;   // Spread angle
    float2 offset;    // Emission point
    float4 color1;    // Particle color start
    float4 color2;    // Particle color end
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
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant Uniforms& u [[buffer(0)]]
) {
    constexpr sampler s(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    float4 color = inputTexture.sample(s, uv);
    
    // Generate particles
    float particleGlow = 0.0;
    float3 particleColor = float3(0.0);
    
    int particleCount = int(u.intensity * 20.0);
    
    for (int i = 0; i < particleCount; i++) {
        float fi = float(i);
        
        // Unique particle properties
        float seed = hash(float2(fi, fi * 2.0));
        float angle = seed * M_PI_F * 2.0 * u.rotation;
        float speed = (0.5 + seed * 0.5) * u.progress;
        
        // Particle lifetime
        float lifetime = fmod(u.time * speed + seed * 10.0, 3.0);
        float fade = 1.0 - lifetime / 3.0;
        
        // Particle position
        float2 particlePos = u.offset + float2(cos(angle), sin(angle)) * lifetime * 0.3;
        particlePos.y -= lifetime * lifetime * 0.05; // Gravity
        
        // Distance to particle
        float dist = length(uv - particlePos);
        
        // Particle glow
        float glow = exp(-dist * 200.0 / u.scale) * fade;
        particleGlow += glow;
        
        // Particle color over lifetime
        float3 pColor = mix(u.color1.rgb, u.color2.rgb, lifetime / 3.0);
        particleColor += pColor * glow;
    }
    
    // Combine with background
    color.rgb = mix(color.rgb, particleColor, clamp(particleGlow, 0.0, 1.0));
    
    return color;
}
"""
}

// Performance metrics tracker
class PerformanceMetrics {
    var frameCount = 0
    var lastFPSUpdate = Date()
    var currentFPS: Double = 0
    var gpuTime: Double = 0
    var drawCallCount = 0
    
    func update() {
        frameCount += 1
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFPSUpdate)
        
        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed
            frameCount = 0
            lastFPSUpdate = now
        }
    }
}

class MetalPreviewView: MTKView {
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState?
    var defaultTexture: MTLTexture?
    var loadedTexture: MTLTexture?
    var startTime = Date()
    var uniforms = StandardUniforms()
    var lastError: String?
    var metrics = PerformanceMetrics()
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        setupMetal()
        createDefaultTexture()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        
        clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1)
        colorPixelFormat = .bgra8Unorm
        
        // Important: Set drawable size explicitly
        drawableSize = CGSize(width: 700, height: 600)
        
        delegate = self
        isPaused = false
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 60
    }
    
    func createDefaultTexture() {
        // Create a checkerboard texture as default
        let width = 256
        let height = 256
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        var data = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let checker = ((x / 32) + (y / 32)) % 2 == 0
                let value: UInt8 = checker ? 200 : 100
                data[offset] = value     // R
                data[offset + 1] = value // G
                data[offset + 2] = value // B
                data[offset + 3] = 255   // A
            }
        }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        
        defaultTexture = device?.makeTexture(descriptor: textureDescriptor)
        defaultTexture?.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: bytesPerRow
        )
    }
    
    func loadImage(_ image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let textureLoader = MTKTextureLoader(device: device!)
        do {
            loadedTexture = try textureLoader.newTexture(cgImage: cgImage, options: [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue
            ])
        } catch {
            print("Failed to load texture: \(error)")
        }
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
    
    override func mouseDown(with event: NSEvent) {
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
        metrics.update()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        
        // Set texture
        let texture = loadedTexture ?? defaultTexture
        encoder.setFragmentTexture(texture, index: 0)
        
        // Set uniforms
        var uniformData = uniforms
        encoder.setFragmentBytes(&uniformData, length: MemoryLayout<StandardUniforms>.size, index: 0)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var editorView: NSTextView!
    var previewView: MetalPreviewView!
    var templatePopup: NSPopUpButton!
    var statusLabel: NSTextField!
    var fpsLabel: NSTextField!
    var parameterControls: [String: NSControl] = [:]
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create window
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1400, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Dev Studio - Professional Shader Development"
        
        // Left panel - Template selector and editor (explicit frame)
        let leftPanel = createLeftPanel()
        leftPanel.frame = NSRect(x: 0, y: 0, width: 700, height: 900)
        window.contentView?.addSubview(leftPanel)
        
        // Right panel - Preview and controls (explicit frame)
        let rightPanel = createRightPanel()
        rightPanel.frame = NSRect(x: 700, y: 0, width: 700, height: 900)
        window.contentView?.addSubview(rightPanel)
        
        // Load initial template
        loadTemplate(ShaderTemplates.templates[0])
        
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
    
    func createLeftPanel() -> NSView {
        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 900))
        
        // Template selector
        let templateLabel = NSTextField(labelWithString: "Template:")
        templateLabel.frame = NSRect(x: 10, y: 860, width: 80, height: 20)
        panel.addSubview(templateLabel)
        
        templatePopup = NSPopUpButton(frame: NSRect(x: 90, y: 855, width: 300, height: 30))
        for template in ShaderTemplates.templates {
            templatePopup.addItem(withTitle: "\(template.category) - \(template.name)")
        }
        templatePopup.target = self
        templatePopup.action = #selector(templateSelected)
        panel.addSubview(templatePopup)
        
        // Load image button
        let loadImageButton = NSButton(title: "Load Image", target: self, action: #selector(loadImage))
        loadImageButton.frame = NSRect(x: 400, y: 855, width: 100, height: 30)
        panel.addSubview(loadImageButton)
        
        // Export button
        let exportButton = NSButton(title: "Export Code", target: self, action: #selector(exportCode))
        exportButton.frame = NSRect(x: 510, y: 855, width: 100, height: 30)
        panel.addSubview(exportButton)
        
        // Code editor
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 40, width: 700, height: 810))
        editorView = NSTextView(frame: scrollView.bounds)
        editorView.autoresizingMask = [.width, .height]
        editorView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        editorView.isAutomaticQuoteSubstitutionEnabled = false
        editorView.isRichText = false
        editorView.backgroundColor = NSColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0)
        editorView.textColor = NSColor(red: 0.8, green: 0.85, blue: 0.9, alpha: 1.0)
        editorView.insertionPointColor = .cyan
        editorView.delegate = self
        
        scrollView.documentView = editorView
        scrollView.hasVerticalScroller = true
        panel.addSubview(scrollView)
        
        // Status bar
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.frame = NSRect(x: 10, y: 10, width: 680, height: 20)
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .lightGray
        panel.addSubview(statusLabel)
        
        return panel
    }
    
    func createRightPanel() -> NSView {
        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 900))
        
        // Preview
        previewView = MetalPreviewView(frame: NSRect(x: 0, y: 300, width: 700, height: 600))
        previewView.autoresizingMask = [.width, .height]
        panel.addSubview(previewView)
        
        // Performance metrics
        fpsLabel = NSTextField(labelWithString: "FPS: 0 | GPU: 0ms")
        fpsLabel.frame = NSRect(x: 10, y: 870, width: 200, height: 20)
        fpsLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        fpsLabel.textColor = .green
        panel.addSubview(fpsLabel)
        
        // Device selector
        let deviceLabel = NSTextField(labelWithString: "Target:")
        deviceLabel.frame = NSRect(x: 250, y: 870, width: 50, height: 20)
        panel.addSubview(deviceLabel)
        
        let devicePopup = NSPopUpButton(frame: NSRect(x: 300, y: 865, width: 150, height: 30))
        devicePopup.addItem(withTitle: "iPhone 15 Pro")
        devicePopup.addItem(withTitle: "iPhone 14")
        devicePopup.addItem(withTitle: "iPad Pro M2")
        devicePopup.addItem(withTitle: "Mac (Current)")
        panel.addSubview(devicePopup)
        
        // Parameter controls
        createParameterControls(in: panel)
        
        // Update timer for FPS
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.updateMetrics()
        }
        
        return panel
    }
    
    func createParameterControls(in panel: NSView) {
        let params: [(String, String, Float, Float)] = [
            ("intensity", "Intensity", 0, 2),
            ("progress", "Progress", 0, 1),
            ("scale", "Scale", 0.1, 5),
            ("rotation", "Rotation", -3.14159, 3.14159)
        ]
        
        var yPos: CGFloat = 250
        
        for (key, label, min, max) in params {
            let paramLabel = NSTextField(labelWithString: label)
            paramLabel.frame = NSRect(x: 20, y: yPos, width: 100, height: 20)
            panel.addSubview(paramLabel)
            
            let slider = NSSlider(value: Double((min + max) / 2), minValue: Double(min), maxValue: Double(max),
                                 target: self, action: #selector(parameterChanged(_:)))
            slider.frame = NSRect(x: 120, y: yPos, width: 300, height: 20)
            slider.identifier = NSUserInterfaceItemIdentifier(key)
            panel.addSubview(slider)
            parameterControls[key] = slider
            
            let valueLabel = NSTextField(labelWithString: String(format: "%.2f", slider.floatValue))
            valueLabel.frame = NSRect(x: 430, y: yPos, width: 60, height: 20)
            valueLabel.identifier = NSUserInterfaceItemIdentifier("\(key)_label")
            panel.addSubview(valueLabel)
            parameterControls["\(key)_label"] = valueLabel
            
            yPos -= 40
        }
        
        // Color pickers
        let color1Label = NSTextField(labelWithString: "Color 1")
        color1Label.frame = NSRect(x: 20, y: 50, width: 100, height: 20)
        panel.addSubview(color1Label)
        
        let color1Well = NSColorWell(frame: NSRect(x: 120, y: 45, width: 60, height: 30))
        color1Well.color = .red
        color1Well.target = self
        color1Well.action = #selector(colorChanged(_:))
        color1Well.identifier = NSUserInterfaceItemIdentifier("color1")
        panel.addSubview(color1Well)
        
        let color2Label = NSTextField(labelWithString: "Color 2")
        color2Label.frame = NSRect(x: 200, y: 50, width: 100, height: 20)
        panel.addSubview(color2Label)
        
        let color2Well = NSColorWell(frame: NSRect(x: 300, y: 45, width: 60, height: 30))
        color2Well.color = .blue
        color2Well.target = self
        color2Well.action = #selector(colorChanged(_:))
        color2Well.identifier = NSUserInterfaceItemIdentifier("color2")
        panel.addSubview(color2Well)
    }
    
    @objc func templateSelected(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        if index < ShaderTemplates.templates.count {
            loadTemplate(ShaderTemplates.templates[index])
        }
    }
    
    func loadTemplate(_ template: ShaderTemplate) {
        editorView.string = template.code
        compileShader()
        statusLabel.stringValue = "Loaded: \(template.name) - \(template.description)"
    }
    
    @objc func loadImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.begin { response in
            if response == .OK, let url = panel.url,
               let image = NSImage(contentsOf: url) {
                self.previewView.loadImage(image)
                self.statusLabel.stringValue = "Loaded image: \(url.lastPathComponent)"
            }
        }
    }
    
    @objc func exportCode() {
        let alert = NSAlert()
        alert.messageText = "Export Shader Code"
        alert.informativeText = """
        // Swift Integration Example
        
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(source: shaderCode, options: nil)
        let vertexFunc = library.makeFunction(name: "vertexShader")
        let fragmentFunc = library.makeFunction(name: "fragmentShader")
        
        // Create pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // Set uniforms in render loop
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        """
        alert.addButton(withTitle: "Copy to Clipboard")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(editorView.string, forType: .string)
        }
    }
    
    @objc func parameterChanged(_ sender: NSSlider) {
        guard let key = sender.identifier?.rawValue else { return }
        let value = sender.floatValue
        
        switch key {
        case "intensity":
            previewView.uniforms.intensity = value
        case "progress":
            previewView.uniforms.progress = value
        case "scale":
            previewView.uniforms.scale = value
        case "rotation":
            previewView.uniforms.rotation = value
        default:
            break
        }
        
        // Update value label
        if let label = parameterControls["\(key)_label"] as? NSTextField {
            label.stringValue = String(format: "%.2f", value)
        }
    }
    
    @objc func colorChanged(_ sender: NSColorWell) {
        guard let key = sender.identifier?.rawValue else { return }
        let color = sender.color
        
        var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) = (0, 0, 0, 1)
        color.getRed(&components.red, green: &components.green, blue: &components.blue, alpha: &components.alpha)
        
        let simd = SIMD4<Float>(
            Float(components.red),
            Float(components.green),
            Float(components.blue),
            Float(components.alpha)
        )
        
        if key == "color1" {
            previewView.uniforms.color1 = simd
        } else if key == "color2" {
            previewView.uniforms.color2 = simd
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
    
    func updateMetrics() {
        let fps = previewView.metrics.currentFPS
        fpsLabel.stringValue = String(format: "FPS: %.0f | GPU: ~%.1fms", fps, 1000.0 / max(fps, 1))
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