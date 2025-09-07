#!/usr/bin/env swift

/**
 * Metal Shader Viewer with Exposed Parameters
 * Run with: swift MetalViewerParametric.swift
 */

import Cocoa
import Metal
import MetalKit
import simd

struct Uniforms {
    var time: Float = 0
    var resolution: SIMD2<Float> = SIMD2<Float>(800, 600)
    var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    
    // Exposed parameters
    var complexity: Float = 1.0      // 0.5 to 3.0
    var speed: Float = 1.0           // 0.1 to 3.0
    var colorShift: Float = 0.0      // 0.0 to 1.0
    var intensity: Float = 1.0       // 0.5 to 2.0
    var zoom: Float = 1.0            // 0.5 to 3.0
    var distortion: Float = 0.0      // 0.0 to 1.0
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
    
    fragment float4 fragmentShader(
        VertexOut in [[stage_in]],
        constant Uniforms& u [[buffer(0)]],
        constant int& shaderType [[buffer(1)]]
    ) {
        float2 uv = in.texCoord;
        float2 p = (uv - 0.5) * 2.0 / u.zoom;
        p.x *= u.resolution.x / u.resolution.y;
        
        // Apply distortion
        if (u.distortion > 0.0) {
            float2 dist = float2(
                sin(p.y * 10.0 + u.time * u.speed) * u.distortion * 0.1,
                cos(p.x * 10.0 + u.time * u.speed) * u.distortion * 0.1
            );
            p += dist;
        }
        
        float3 color = float3(0.0);
        
        if (shaderType == 0) {
            // Plasma Fractal with parameters
            float plasma = 0.0;
            float freq = 8.0 * u.complexity;
            plasma += sin(p.x * freq + u.time * 2.0 * u.speed);
            plasma += sin(p.y * freq * 0.75 + u.time * 1.5 * u.speed);
            plasma += sin(length(p) * freq - u.time * u.speed);
            plasma += noise(p * 3.0 * u.complexity + u.time * 0.5 * u.speed) * 2.0;
            plasma /= 8.0;
            
            color = palette(plasma + u.time * 0.1 * u.speed + u.colorShift);
            float glow = exp(-length(p - (u.mouse - 0.5) * 2.0) * 0.5) * 0.3 * u.intensity;
            color += float3(glow * 0.5, glow * 0.7, glow);
            
        } else if (shaderType == 1) {
            // Kaleidoscope with parameters
            float2 center = float2(0.0);
            float angle = atan2(p.y, p.x) + u.time * u.speed;
            float radius = length(p) * u.zoom;
            int segments = 6 + int(u.complexity * 6);
            float segmentAngle = 2.0 * M_PI_F / float(segments);
            angle = fmod(angle, segmentAngle);
            if (int(atan2(p.y, p.x) / segmentAngle) % 2 == 1) {
                angle = segmentAngle - angle;
            }
            float2 kp = radius * float2(cos(angle), sin(angle));
            
            float2 blockUV = floor(kp * 8.0 * u.complexity) / 8.0;
            float colorIndex = hash(blockUV) * 4.0 + u.colorShift * 4.0;
            
            color = colorIndex < 1.0 ? float3(1.0, 0.2, 0.2) :
                    colorIndex < 2.0 ? float3(0.2, 1.0, 0.2) :
                    colorIndex < 3.0 ? float3(0.2, 0.4, 1.0) :
                                      float3(1.0, 0.9, 0.2);
            
            color *= 0.7 + 0.3 * sin(u.time * 2.0 * u.speed) * u.intensity;
            
        } else if (shaderType == 2) {
            // Liquid Metal with parameters
            float flow = noise(p * 3.0 * u.complexity + u.time * 0.5 * u.speed);
            flow += noise(p * 6.0 * u.complexity - u.time * 0.3 * u.speed) * 0.5;
            flow += noise(p * 12.0 * u.complexity + u.time * 0.7 * u.speed) * 0.25;
            
            float2 distort = float2(
                sin(p.y * 10.0 * u.complexity + u.time * u.speed) * 0.02 * u.distortion,
                cos(p.x * 10.0 * u.complexity + u.time * u.speed) * 0.02 * u.distortion
            );
            
            float metallic = noise((p + distort) * 5.0 * u.complexity + flow);
            
            color.r = metallic * (0.7 + u.colorShift * 0.3) + flow * 0.3;
            color.g = metallic * 0.8 + flow * 0.2;
            color.b = metallic * (0.9 - u.colorShift * 0.3) + flow * 0.1;
            
            float highlight = pow(max(0.0, 1.0 - length(p - (u.mouse - 0.5) * 2.0)), 3.0);
            color += highlight * 0.5 * u.intensity;
            
        } else if (shaderType == 3) {
            // Neon Grid with parameters
            float perspective = 1.0 / (1.0 + p.y * 0.5 * u.zoom);
            p.x *= perspective;
            
            float gridScale = 10.0 * u.complexity;
            float2 grid = abs(fract(p * gridScale - u.time * float2(0, 1) * u.speed) - 0.5);
            float lines = smoothstep(0.0, 0.02 / perspective, min(grid.x, grid.y));
            
            float wave = sin(p.y * 5.0 * u.complexity - u.time * 3.0 * u.speed) * 0.5 + 0.5;
            color.r = lines * (1.0 - wave) * (1.0 - u.colorShift);
            color.g = lines * wave * (0.5 + u.colorShift * 0.5);
            color.b = lines * (1.0 - u.colorShift * 0.5);
            
            color += float3(0.1, 0.0, 0.2) * (1.0 - lines) * perspective * u.intensity;
            color *= smoothstep(-1.0, 0.5, p.y);
            
            float spotlight = pow(max(0.0, 1.0 - length((uv - u.mouse) * float2(u.resolution.x / u.resolution.y, 1.0))), 3.0);
            color += float3(0.2, 0.5, 1.0) * spotlight * u.intensity;
            
        } else {
            // Rainbow Spiral with parameters
            float radius = length(p) * u.zoom;
            float angle = atan2(p.y, p.x);
            float spiral = angle + radius * 10.0 * u.complexity - u.time * 2.0 * u.speed;
            spiral = fract(spiral / (2.0 * M_PI_F));
            
            float hue = spiral + radius * 0.5 + u.time * 0.1 * u.speed + u.colorShift;
            color = hsv2rgb(float3(hue, 1.0, 1.0));
            
            float pulse = sin(radius * 20.0 * u.complexity - u.time * 5.0 * u.speed) * 0.5 + 0.5;
            color *= (0.5 + pulse * 0.5) * u.intensity;
            
            float2 mouseOffset = p - (u.mouse - 0.5) * 2.0;
            float warp = exp(-length(mouseOffset) * 3.0);
            color *= 1.0 + warp * 0.5 * u.distortion;
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
    var sliders: [String: NSSlider] = [:]
    var labels: [String: NSTextField] = [:]
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Shader Gallery - Interactive Parameters"
        
        // Metal view takes up left side
        metalView = MetalShaderView(frame: NSRect(x: 0, y: 0, width: 700, height: 700))
        metalView.autoresizingMask = [.width, .height]
        
        let trackingArea = NSTrackingArea(
            rect: metalView.bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: metalView,
            userInfo: nil
        )
        metalView.addTrackingArea(trackingArea)
        
        // Control panel on right side
        let controlPanel = NSView(frame: NSRect(x: 700, y: 0, width: 300, height: 700))
        controlPanel.autoresizingMask = [.minXMargin, .height]
        controlPanel.wantsLayer = true
        controlPanel.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor
        
        // Title
        let title = NSTextField(labelWithString: "Shader Parameters")
        title.frame = NSRect(x: 20, y: 650, width: 260, height: 30)
        title.textColor = .white
        title.font = .boldSystemFont(ofSize: 18)
        controlPanel.addSubview(title)
        
        // Shader dropdown
        popup = NSPopUpButton(frame: NSRect(x: 20, y: 610, width: 260, height: 30))
        for name in metalView.shaderNames {
            popup.addItem(withTitle: name)
        }
        popup.target = self
        popup.action = #selector(shaderChanged)
        controlPanel.addSubview(popup)
        
        // Create sliders for parameters
        let parameters: [(String, String, Float, Float, Float)] = [
            ("complexity", "Complexity", 0.5, 3.0, 1.0),
            ("speed", "Speed", 0.1, 3.0, 1.0),
            ("colorShift", "Color Shift", 0.0, 1.0, 0.0),
            ("intensity", "Intensity", 0.5, 2.0, 1.0),
            ("zoom", "Zoom", 0.5, 3.0, 1.0),
            ("distortion", "Distortion", 0.0, 1.0, 0.0)
        ]
        
        var yPos: CGFloat = 550
        
        for (key, label, min, max, initial) in parameters {
            // Label
            let paramLabel = NSTextField(labelWithString: label)
            paramLabel.frame = NSRect(x: 20, y: yPos, width: 120, height: 20)
            paramLabel.textColor = .white
            paramLabel.font = .systemFont(ofSize: 14)
            controlPanel.addSubview(paramLabel)
            
            // Value label
            let valueLabel = NSTextField(labelWithString: String(format: "%.2f", initial))
            valueLabel.frame = NSRect(x: 240, y: yPos, width: 40, height: 20)
            valueLabel.textColor = .cyan
            valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            valueLabel.alignment = .right
            controlPanel.addSubview(valueLabel)
            labels[key] = valueLabel
            
            // Slider
            let slider = NSSlider(value: Double(initial), minValue: Double(min), maxValue: Double(max),
                                 target: self, action: #selector(sliderChanged(_:)))
            slider.frame = NSRect(x: 20, y: yPos - 25, width: 260, height: 20)
            slider.identifier = NSUserInterfaceItemIdentifier(key)
            controlPanel.addSubview(slider)
            sliders[key] = slider
            
            yPos -= 60
        }
        
        // Info label
        let info = NSTextField(labelWithString: "Move mouse to interact • Press 1-5 to switch shaders")
        info.frame = NSRect(x: 20, y: 20, width: 260, height: 40)
        info.textColor = .gray
        info.font = .systemFont(ofSize: 11)
        info.maximumNumberOfLines = 2
        controlPanel.addSubview(info)
        
        // Reset button
        let resetButton = NSButton(title: "Reset Parameters", target: self, action: #selector(resetParameters))
        resetButton.frame = NSRect(x: 20, y: 70, width: 260, height: 30)
        controlPanel.addSubview(resetButton)
        
        window.contentView?.addSubview(metalView)
        window.contentView?.addSubview(controlPanel)
        
        window.makeKeyAndOrderFront(nil)
    }
    
    @objc func shaderChanged(_ sender: NSPopUpButton) {
        metalView.currentShader = sender.indexOfSelectedItem
        metalView.startTime = Date()
    }
    
    @objc func sliderChanged(_ sender: NSSlider) {
        guard let key = sender.identifier?.rawValue else { return }
        let value = Float(sender.doubleValue)
        
        // Update the uniform value
        switch key {
        case "complexity":
            metalView.uniforms.complexity = value
        case "speed":
            metalView.uniforms.speed = value
        case "colorShift":
            metalView.uniforms.colorShift = value
        case "intensity":
            metalView.uniforms.intensity = value
        case "zoom":
            metalView.uniforms.zoom = value
        case "distortion":
            metalView.uniforms.distortion = value
        default:
            break
        }
        
        // Update the label
        labels[key]?.stringValue = String(format: "%.2f", value)
    }
    
    @objc func resetParameters() {
        metalView.uniforms.complexity = 1.0
        metalView.uniforms.speed = 1.0
        metalView.uniforms.colorShift = 0.0
        metalView.uniforms.intensity = 1.0
        metalView.uniforms.zoom = 1.0
        metalView.uniforms.distortion = 0.0
        
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