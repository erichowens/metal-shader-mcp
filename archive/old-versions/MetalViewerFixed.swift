#!/usr/bin/env swift

/**
 * Fixed Metal Shader Viewer with Multiple Shaders
 * Run with: swift MetalViewerFixed.swift
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

class MetalShaderView: MTKView {
    var commandQueue: MTLCommandQueue!
    var pipelineStates: [MTLRenderPipelineState] = []
    var currentShader = 0
    var startTime = Date()
    var uniforms = Uniforms()
    
    let shaderNames = ["Plasma Fractal", "Kaleidoscope", "Liquid Metal", "Neon Grid", "Rainbow Spiral"]
    
    let shaderCode = """
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
    
    // Helper functions
    float hash(float2 p) {
        p = fract(p * float2(123.34, 456.21));
        p += dot(p, p + 45.32);
        return fract(p.x * p.y);
    }
    
    float noise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        
        float a = hash(i);
        float b = hash(i + float2(1, 0));
        float c = hash(i + float2(0, 1));
        float d = hash(i + float2(1, 1));
        
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }
    
    float3 hsv2rgb(float3 c) {
        float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
        return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    }
    
    float3 palette(float t) {
        float3 a = float3(0.5, 0.5, 0.5);
        float3 b = float3(0.5, 0.5, 0.5);
        float3 c = float3(1.0, 1.0, 1.0);
        float3 d = float3(0.0, 0.10, 0.20);
        return a + b * cos(6.28318 * (c * t + d));
    }
    
    // Main fragment shader that switches between effects
    fragment float4 fragmentShader(
        VertexOut in [[stage_in]],
        constant Uniforms& u [[buffer(0)]],
        constant int& shaderType [[buffer(1)]]
    ) {
        float2 uv = in.texCoord;
        float2 p = (uv - 0.5) * 2.0;
        p.x *= u.resolution.x / u.resolution.y;
        
        float3 color = float3(0.0);
        
        if (shaderType == 0) {
            // Plasma Fractal
            float plasma = 0.0;
            plasma += sin(p.x * 8.0 + u.time * 2.0);
            plasma += sin(p.y * 6.0 + u.time * 1.5);
            plasma += sin(length(p) * 8.0 - u.time);
            plasma += noise(p * 3.0 + u.time * 0.5) * 2.0;
            plasma /= 8.0;
            
            color = palette(plasma + u.time * 0.1);
            float glow = exp(-length(p - (u.mouse - 0.5) * 2.0) * 0.5) * 0.3;
            color += float3(glow * 0.5, glow * 0.7, glow);
            
        } else if (shaderType == 1) {
            // Kaleidoscope
            float2 center = float2(0.0);
            float angle = atan2(p.y, p.x) + u.time;
            float radius = length(p);
            int segments = 6 + int(u.mouse.x * 6);
            float segmentAngle = 2.0 * M_PI_F / float(segments);
            angle = fmod(angle, segmentAngle);
            if (int(atan2(p.y, p.x) / segmentAngle) % 2 == 1) {
                angle = segmentAngle - angle;
            }
            float2 kp = radius * float2(cos(angle), sin(angle));
            
            float2 blockUV = floor(kp * 8.0) / 8.0;
            float colorIndex = hash(blockUV) * 4.0;
            
            color = colorIndex < 1.0 ? float3(1.0, 0.2, 0.2) :
                    colorIndex < 2.0 ? float3(0.2, 1.0, 0.2) :
                    colorIndex < 3.0 ? float3(0.2, 0.4, 1.0) :
                                      float3(1.0, 0.9, 0.2);
            
            color *= 0.7 + 0.3 * sin(u.time * 2.0);
            
        } else if (shaderType == 2) {
            // Liquid Metal
            float flow = noise(p * 3.0 + u.time * 0.5);
            flow += noise(p * 6.0 - u.time * 0.3) * 0.5;
            flow += noise(p * 12.0 + u.time * 0.7) * 0.25;
            
            float2 distort = float2(
                sin(p.y * 10.0 + u.time) * 0.02,
                cos(p.x * 10.0 + u.time) * 0.02
            );
            
            float metallic = noise((p + distort) * 5.0 + flow);
            
            color.r = metallic * 0.7 + flow * 0.3;
            color.g = metallic * 0.8 + flow * 0.2;
            color.b = metallic * 0.9 + flow * 0.1;
            
            float highlight = pow(max(0.0, 1.0 - length(p - (u.mouse - 0.5) * 2.0)), 3.0);
            color += highlight * 0.5;
            
        } else if (shaderType == 3) {
            // Neon Grid
            float perspective = 1.0 / (1.0 + p.y * 0.5);
            p.x *= perspective;
            
            float2 grid = abs(fract(p * 10.0 - u.time * float2(0, 1)) - 0.5);
            float lines = smoothstep(0.0, 0.02 / perspective, min(grid.x, grid.y));
            
            float wave = sin(p.y * 5.0 - u.time * 3.0) * 0.5 + 0.5;
            color.r = lines * (1.0 - wave);
            color.g = lines * wave * 0.5;
            color.b = lines;
            
            color += float3(0.1, 0.0, 0.2) * (1.0 - lines) * perspective;
            color *= smoothstep(-1.0, 0.5, p.y);
            
            float spotlight = pow(max(0.0, 1.0 - length((uv - u.mouse) * float2(u.resolution.x / u.resolution.y, 1.0))), 3.0);
            color += float3(0.2, 0.5, 1.0) * spotlight;
            
        } else {
            // Rainbow Spiral
            float radius = length(p);
            float angle = atan2(p.y, p.x);
            float spiral = angle + radius * 10.0 - u.time * 2.0;
            spiral = fract(spiral / (2.0 * M_PI_F));
            
            float hue = spiral + radius * 0.5 + u.time * 0.1;
            color = hsv2rgb(float3(hue, 1.0, 1.0));
            
            float pulse = sin(radius * 20.0 - u.time * 5.0) * 0.5 + 0.5;
            color *= 0.5 + pulse * 0.5;
            
            float2 mouseOffset = p - (u.mouse - 0.5) * 2.0;
            float warp = exp(-length(mouseOffset) * 3.0);
            color *= 1.0 + warp * 0.5;
            color *= smoothstep(1.0, 0.8, radius);
        }
        
        // Tone mapping
        color = color / (color + 1.0);
        color = pow(color, float3(0.85));
        
        return float4(color, 1.0);
    }
    """
    
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
        
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        colorPixelFormat = .bgra8Unorm
        
        do {
            let library = try device?.makeLibrary(source: shaderCode, options: nil)
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
            print("Error: \(error)")
        }
        
        delegate = self
        isPaused = false
        enableSetNeedsDisplay = false
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        uniforms.mouse = SIMD2<Float>(
            Float(location.x / bounds.width),
            Float(1.0 - location.y / bounds.height)
        )
    }
}

extension MetalShaderView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
    }
    
    func draw(in view: MTKView) {
        guard let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              !pipelineStates.isEmpty else { return }
        
        uniforms.time = Float(Date().timeIntervalSince(startTime))
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        
        encoder.setRenderPipelineState(pipelineStates[0])
        
        var uniformData = uniforms
        encoder.setFragmentBytes(&uniformData, length: MemoryLayout<Uniforms>.size, index: 0)
        
        var shaderType = Int32(currentShader)
        encoder.setFragmentBytes(&shaderType, length: MemoryLayout<Int32>.size, index: 1)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var metalView: MetalShaderView!
    var popup: NSPopUpButton!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Shader Gallery"
        
        metalView = MetalShaderView(frame: window.contentView!.bounds)
        metalView.autoresizingMask = [.width, .height]
        
        let trackingArea = NSTrackingArea(
            rect: metalView.bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: metalView,
            userInfo: nil
        )
        metalView.addTrackingArea(trackingArea)
        
        // Create dropdown
        popup = NSPopUpButton(frame: NSRect(x: 20, y: window.contentView!.bounds.height - 50, width: 200, height: 30))
        popup.autoresizingMask = [.maxXMargin, .minYMargin]
        
        for name in metalView.shaderNames {
            popup.addItem(withTitle: name)
        }
        
        popup.target = self
        popup.action = #selector(shaderChanged)
        
        // Info label
        let info = NSTextField(labelWithString: "Move mouse to interact • Press 1-5 to switch")
        info.frame = NSRect(x: 20, y: 20, width: 400, height: 20)
        info.autoresizingMask = [.maxXMargin, .maxYMargin]
        info.textColor = .white
        info.font = .systemFont(ofSize: 12)
        
        window.contentView?.addSubview(metalView)
        window.contentView?.addSubview(popup)
        window.contentView?.addSubview(info)
        
        window.makeKeyAndOrderFront(nil)
    }
    
    @objc func shaderChanged(_ sender: NSPopUpButton) {
        metalView.currentShader = sender.indexOfSelectedItem
        metalView.startTime = Date()
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