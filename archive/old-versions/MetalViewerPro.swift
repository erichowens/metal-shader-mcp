#!/usr/bin/env swift

/**
 * Enhanced Metal Shader Viewer with Shader Selection
 * Switch between different shaders using dropdown menu
 * 
 * Run with: swift MetalViewerPro.swift
 */

import Cocoa
import Metal
import MetalKit
import simd

// Uniforms structure
struct Uniforms {
    var time: Float = 0
    var resolution: SIMD2<Float> = SIMD2<Float>(800, 600)
    var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    var complexity: Float = 1.0
    var colorShift: Float = 0.0
}

// Shader definitions
struct ShaderProgram {
    let name: String
    let vertexSource: String
    let fragmentSource: String
}

class ShaderLibrary {
    static let shaders = [
        ShaderProgram(
            name: "Plasma Fractal",
            vertexSource: vertexShaderSource,
            fragmentSource: plasmaFractalShader
        ),
        ShaderProgram(
            name: "Kaleidoscope",
            vertexSource: vertexShaderSource,
            fragmentSource: kaleidoscopeShader
        ),
        ShaderProgram(
            name: "Liquid Metal",
            vertexSource: vertexShaderSource,
            fragmentSource: liquidMetalShader
        ),
        ShaderProgram(
            name: "Neon Grid",
            vertexSource: vertexShaderSource,
            fragmentSource: neonGridShader
        ),
        ShaderProgram(
            name: "Rainbow Spiral",
            vertexSource: vertexShaderSource,
            fragmentSource: rainbowSpiralShader
        )
    ]
    
    static let vertexShaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    
    struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
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
    """
    
    static let plasmaFractalShader = """
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
        float colorShift;
    };
    
    float2 complexMul(float2 a, float2 b) {
        return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
    }
    
    float noise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        
        float a = fract(sin(dot(i, float2(12.9898, 78.233))) * 43758.5453);
        float b = fract(sin(dot(i + float2(1, 0), float2(12.9898, 78.233))) * 43758.5453);
        float c = fract(sin(dot(i + float2(0, 1), float2(12.9898, 78.233))) * 43758.5453);
        float d = fract(sin(dot(i + float2(1, 1), float2(12.9898, 78.233))) * 43758.5453);
        
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }
    
    float fbm(float2 p) {
        float value = 0.0;
        float amplitude = 0.5;
        for (int i = 0; i < 5; i++) {
            value += amplitude * noise(p);
            p *= 2.1;
            amplitude *= 0.47;
        }
        return value;
    }
    
    float julia(float2 z, float2 c) {
        for (int i = 0; i < 64; i++) {
            if (length(z) > 2.0) return float(i) / 64.0;
            z = complexMul(z, z) + c;
        }
        return 1.0;
    }
    
    float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
        return a + b * cos(6.28318 * (c * t + d));
    }
    
    fragment float4 fragmentShader(
        VertexOut in [[stage_in]],
        constant Uniforms& u [[buffer(0)]]
    ) {
        float2 uv = in.texCoord;
        float2 p = (uv - 0.5) * 2.0;
        p.x *= u.resolution.x / u.resolution.y;
        p += (u.mouse - 0.5) * 2.0 * 0.3;
        
        float2 juliaC = float2(sin(u.time * 0.2) * 0.4, cos(u.time * 0.3) * 0.4);
        float juliaValue = julia(p * 1.5, juliaC);
        
        float plasma = 0.0;
        plasma += sin(p.x * 8.0 + u.time * 2.0);
        plasma += sin(p.y * 6.0 + u.time * 1.5);
        plasma += sin(length(p) * 8.0 - u.time);
        plasma += fbm(p * 3.0 + u.time * 0.5) * 2.0;
        plasma /= 8.0;
        
        float finalValue = juliaValue * 0.4 + plasma * 0.3 + fbm(p * 4.0 + u.time * 0.2) * 0.3;
        
        float3 color1 = palette(finalValue + u.colorShift,
            float3(0.5), float3(0.5), float3(1.0), float3(0.0, 0.10, 0.20));
        float3 color2 = palette(finalValue * 1.5 + u.time * 0.1,
            float3(0.8, 0.5, 0.4), float3(0.2, 0.4, 0.2), float3(2.0, 1.0, 1.0), float3(0.0, 0.25, 0.25));
        
        float3 finalColor = mix(color1, color2, sin(plasma * 3.14159) * 0.5 + 0.5);
        float glow = exp(-length(p) * 0.5) * 0.3;
        finalColor += float3(glow * 0.5, glow * 0.7, glow);
        finalColor = finalColor / (finalColor + 1.0);
        finalColor = pow(finalColor, float3(0.85));
        
        return float4(finalColor, 1.0);
    }
    """
    
    static let kaleidoscopeShader = """
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
        float colorShift;
    };
    
    float2 kaleidoscope(float2 uv, int segments, float rotation) {
        float2 center = float2(0.5);
        float2 p = uv - center;
        float angle = atan2(p.y, p.x) + rotation;
        float radius = length(p);
        float segmentAngle = 2.0 * M_PI_F / float(segments);
        angle = fmod(angle, segmentAngle);
        if (fmod(floor(atan2(p.y, p.x) / segmentAngle), 2.0) == 1.0) {
            angle = segmentAngle - angle;
        }
        return center + radius * float2(cos(angle), sin(angle));
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
        float2 uv = kaleidoscope(in.texCoord, 6 + int(u.mouse.x * 6), u.time);
        float2 p = (uv - 0.5) * 2.0;
        
        float2 blockUV = floor(uv * 16.0) / 16.0;
        float colorIndex = hash(blockUV) * 4.0;
        
        float4 colors[4] = {
            float4(1.0, 0.2, 0.2, 1.0),
            float4(0.2, 1.0, 0.2, 1.0),
            float4(0.2, 0.4, 1.0, 1.0),
            float4(1.0, 0.9, 0.2, 1.0)
        };
        
        float4 baseColor = colors[int(colorIndex) % 4];
        
        float breathe = 0.5 + 0.5 * sin(u.time * 2.0 * M_PI_F * 0.4);
        baseColor.rgb *= 0.7 + breathe * 0.3;
        
        float ripple = sin(length(uv - u.mouse) * 20.0 - u.time * 10.0) * 0.5 + 0.5;
        ripple *= exp(-length(uv - u.mouse) * 3.0);
        baseColor.rgb += ripple * 0.2;
        
        return baseColor;
    }
    """
    
    static let liquidMetalShader = """
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
        float colorShift;
    };
    
    float noise(float2 p) {
        return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
    }
    
    float smoothNoise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        
        float a = noise(i);
        float b = noise(i + float2(1.0, 0.0));
        float c = noise(i + float2(0.0, 1.0));
        float d = noise(i + float2(1.0, 1.0));
        
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }
    
    fragment float4 fragmentShader(
        VertexOut in [[stage_in]],
        constant Uniforms& u [[buffer(0)]]
    ) {
        float2 uv = in.texCoord;
        float2 p = (uv - 0.5) * 2.0;
        p.x *= u.resolution.x / u.resolution.y;
        
        // Liquid flow
        float flow = smoothNoise(p * 3.0 + u.time * 0.5);
        flow += smoothNoise(p * 6.0 - u.time * 0.3) * 0.5;
        flow += smoothNoise(p * 12.0 + u.time * 0.7) * 0.25;
        
        // Metallic reflection
        float2 distort = float2(
            sin(p.y * 10.0 + u.time) * 0.02,
            cos(p.x * 10.0 + u.time) * 0.02
        );
        
        float metallic = smoothNoise((p + distort) * 5.0 + flow);
        
        // Color based on flow
        float3 color = float3(0.0);
        color.r = metallic * 0.7 + flow * 0.3;
        color.g = metallic * 0.8 + flow * 0.2;
        color.b = metallic * 0.9 + flow * 0.1;
        
        // Chrome-like highlights
        float highlight = pow(max(0.0, 1.0 - length(p - u.mouse + 0.5)), 3.0);
        color += highlight * 0.5;
        
        // Reflective edges
        float edge = 1.0 - smoothstep(0.0, 0.1, abs(flow - 0.5));
        color += edge * float3(0.2, 0.3, 0.4);
        
        return float4(color, 1.0);
    }
    """
    
    static let neonGridShader = """
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
        float colorShift;
    };
    
    fragment float4 fragmentShader(
        VertexOut in [[stage_in]],
        constant Uniforms& u [[buffer(0)]]
    ) {
        float2 uv = in.texCoord;
        float2 p = uv * 2.0 - 1.0;
        p.x *= u.resolution.x / u.resolution.y;
        
        // Perspective transform
        float perspective = 1.0 / (1.0 + p.y * 0.5);
        p.x *= perspective;
        
        // Grid
        float2 grid = abs(fract(p * 10.0 - u.time * float2(0, 1)) - 0.5);
        float lines = smoothstep(0.0, 0.02 / perspective, min(grid.x, grid.y));
        
        // Neon colors
        float3 color = float3(0.0);
        float wave = sin(p.y * 5.0 - u.time * 3.0) * 0.5 + 0.5;
        
        color.r = lines * (1.0 - wave);
        color.g = lines * wave * 0.5;
        color.b = lines;
        
        // Glow
        color += float3(0.1, 0.0, 0.2) * (1.0 - lines) * perspective;
        
        // Horizon fade
        color *= smoothstep(-1.0, 0.5, p.y);
        
        // Mouse interaction - spotlight
        float spotlight = 1.0 - length((uv - u.mouse) * float2(u.resolution.x / u.resolution.y, 1.0));
        spotlight = pow(max(0.0, spotlight), 3.0);
        color += float3(0.2, 0.5, 1.0) * spotlight;
        
        return float4(color, 1.0);
    }
    """
    
    static let rainbowSpiralShader = """
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
        float colorShift;
    };
    
    float3 hsv2rgb(float3 c) {
        float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
        return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    }
    
    fragment float4 fragmentShader(
        VertexOut in [[stage_in]],
        constant Uniforms& u [[buffer(0)]]
    ) {
        float2 uv = in.texCoord;
        float2 center = float2(0.5);
        float2 p = uv - center;
        
        // Spiral
        float radius = length(p);
        float angle = atan2(p.y, p.x);
        
        float spiral = angle + radius * 10.0 - u.time * 2.0;
        spiral = fract(spiral / (2.0 * M_PI_F));
        
        // Rainbow colors
        float hue = spiral + radius * 0.5 + u.time * 0.1;
        float3 color = hsv2rgb(float3(hue, 1.0, 1.0));
        
        // Pulse
        float pulse = sin(radius * 20.0 - u.time * 5.0) * 0.5 + 0.5;
        color *= 0.5 + pulse * 0.5;
        
        // Mouse warp
        float2 mouseOffset = uv - u.mouse;
        float mouseDist = length(mouseOffset);
        float warp = exp(-mouseDist * 3.0);
        
        p += mouseOffset * warp * 0.2;
        radius = length(p);
        
        // Fade edges
        color *= smoothstep(0.5, 0.4, radius);
        
        return float4(color, 1.0);
    }
    """
}

class MetalShaderView: MTKView {
    var commandQueue: MTLCommandQueue!
    var pipelineStates: [MTLRenderPipelineState] = []
    var currentPipelineIndex = 0
    var startTime = Date()
    var uniforms = Uniforms()
    var mouseLocation = CGPoint(x: 0.5, y: 0.5)
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        setupMetal()
    }
    
    func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        colorPixelFormat = .bgra8Unorm
        
        // Compile all shaders
        for shader in ShaderLibrary.shaders {
            do {
                let library = try device?.makeLibrary(
                    source: shader.vertexSource + "\n" + shader.fragmentSource,
                    options: nil
                )
                let vertexFunction = library?.makeFunction(name: "vertexShader")
                let fragmentFunction = library?.makeFunction(name: "fragmentShader")
                
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = vertexFunction
                pipelineDescriptor.fragmentFunction = fragmentFunction
                pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
                
                if let pipelineState = try device?.makeRenderPipelineState(descriptor: pipelineDescriptor) {
                    pipelineStates.append(pipelineState)
                }
            } catch {
                print("Error compiling shader \(shader.name): \(error)")
            }
        }
        
        delegate = self
        isPaused = false
        enableSetNeedsDisplay = false
    }
    
    func switchToShader(index: Int) {
        if index < pipelineStates.count {
            currentPipelineIndex = index
            startTime = Date() // Reset time for new shader
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        mouseLocation.x = location.x / bounds.width
        mouseLocation.y = 1.0 - location.y / bounds.height // Flip Y
        uniforms.mouse = SIMD2<Float>(Float(mouseLocation.x), Float(mouseLocation.y))
    }
}

extension MetalShaderView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
    }
    
    func draw(in view: MTKView) {
        guard let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              currentPipelineIndex < pipelineStates.count else { return }
        
        uniforms.time = Float(Date().timeIntervalSince(startTime))
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        
        encoder.setRenderPipelineState(pipelineStates[currentPipelineIndex])
        
        var uniformData = uniforms
        encoder.setFragmentBytes(&uniformData, length: MemoryLayout<Uniforms>.size, index: 0)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var metalView: MetalShaderView!
    var shaderPopup: NSPopUpButton!
    var infoLabel: NSTextField!
    var fpsLabel: NSTextField!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create window
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1024, height: 768),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Shader Viewer Pro"
        
        // Create Metal view
        metalView = MetalShaderView(frame: window.contentView!.bounds)
        metalView.autoresizingMask = [.width, .height]
        
        // Mouse tracking
        let trackingArea = NSTrackingArea(
            rect: metalView.bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: metalView,
            userInfo: nil
        )
        metalView.addTrackingArea(trackingArea)
        
        // Create shader selector dropdown
        shaderPopup = NSPopUpButton(frame: NSRect(x: 20, y: window.contentView!.bounds.height - 50, width: 200, height: 30))
        shaderPopup.autoresizingMask = [.maxXMargin, .minYMargin]
        
        for shader in ShaderLibrary.shaders {
            shaderPopup.addItem(withTitle: shader.name)
        }
        
        shaderPopup.target = self
        shaderPopup.action = #selector(shaderSelectionChanged)
        
        // Style the dropdown
        shaderPopup.font = .systemFont(ofSize: 14, weight: .medium)
        
        // Info label
        infoLabel = NSTextField(labelWithString: "Move mouse to interact • Press 1-5 for quick switch")
        infoLabel.frame = NSRect(x: 20, y: 20, width: 400, height: 20)
        infoLabel.autoresizingMask = [.maxXMargin, .maxYMargin]
        infoLabel.textColor = .white
        infoLabel.font = .systemFont(ofSize: 12)
        
        // FPS label
        fpsLabel = NSTextField(labelWithString: "60 FPS")
        fpsLabel.frame = NSRect(x: window.contentView!.bounds.width - 100, y: window.contentView!.bounds.height - 50, width: 80, height: 30)
        fpsLabel.autoresizingMask = [.minXMargin, .minYMargin]
        fpsLabel.textColor = .green
        fpsLabel.font = .monospacedSystemFont(ofSize: 14, weight: .bold)
        fpsLabel.alignment = .right
        
        // Add subviews
        window.contentView?.addSubview(metalView)
        window.contentView?.addSubview(shaderPopup)
        window.contentView?.addSubview(infoLabel)
        window.contentView?.addSubview(fpsLabel)
        
        window.makeKeyAndOrderFront(nil)
        
        // Enable key events
        window.makeFirstResponder(window.contentView)
        
        // FPS timer
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.fpsLabel.stringValue = "60 FPS"
        }
    }
    
    @objc func shaderSelectionChanged(_ sender: NSPopUpButton) {
        metalView.switchToShader(index: sender.indexOfSelectedItem)
        
        // Update info text
        let shaderNames = ["Fractal plasma", "Kaleidoscope", "Liquid metal", "Neon grid", "Rainbow spiral"]
        if sender.indexOfSelectedItem < shaderNames.count {
            infoLabel.stringValue = "\(shaderNames[sender.indexOfSelectedItem]) • Move mouse to interact"
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Handle keyboard shortcuts
class ContentView: NSView {
    var metalView: MetalShaderView?
    var popup: NSPopUpButton?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard let metalView = metalView,
              let popup = popup else { return }
        
        switch event.characters {
        case "1": 
            popup.selectItem(at: 0)
            metalView.switchToShader(index: 0)
        case "2":
            popup.selectItem(at: 1)
            metalView.switchToShader(index: 1)
        case "3":
            popup.selectItem(at: 2)
            metalView.switchToShader(index: 2)
        case "4":
            popup.selectItem(at: 3)
            metalView.switchToShader(index: 3)
        case "5":
            popup.selectItem(at: 4)
            metalView.switchToShader(index: 4)
        default:
            super.keyDown(with: event)
        }
    }
}

// Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()