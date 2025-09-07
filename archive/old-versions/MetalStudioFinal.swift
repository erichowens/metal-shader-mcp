#!/usr/bin/env swift

/**
 * Metal Studio Final - Professional Metal Shader Development
 * With shader-specific parameters and working export
 */

import Cocoa
import Metal
import MetalKit
import simd

// MARK: - Shader Templates with Specific Parameters

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
    let uniformName: String // Maps to shader uniform
}

// MARK: - Dynamic Uniforms

struct DynamicUniforms {
    var time: Float = 0
    var resolution: SIMD2<Float> = SIMD2<Float>(800, 600)
    var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    
    // Dynamic parameters (up to 8 custom parameters)
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
    static let templates: [ShaderTemplate] = [
        // GRADIENT SHADER
        ShaderTemplate(
            name: "Gradient Blend",
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
                float param4; // blend_smooth
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
                float angle = u.param1 * 3.14159;
                float2 dir = float2(cos(angle), sin(angle));
                float gradient = dot(uv - 0.5, dir) + 0.5;
                
                // Add wave distortion
                gradient += sin(gradient * 10.0 + u.time) * u.param3 * 0.1;
                
                // Color shift creates different gradients
                float3 color1 = float3(0.1 + u.param2, 0.2, 0.5 - u.param2);
                float3 color2 = float3(0.9 - u.param2, 0.4 + u.param2, 0.1);
                
                // Smoothstep for blend control
                gradient = smoothstep(0.0, u.param4, gradient);
                
                float3 color = mix(color1, color2, gradient);
                return float4(color, 1.0);
            }
            """,
            parameters: [
                ParameterDefinition(name: "param1", label: "Angle", min: 0, max: 2, defaultValue: 0.25, uniformName: "angle"),
                ParameterDefinition(name: "param2", label: "Color Shift", min: 0, max: 1, defaultValue: 0, uniformName: "color_shift"),
                ParameterDefinition(name: "param3", label: "Wave", min: 0, max: 1, defaultValue: 0.3, uniformName: "wave_amount"),
                ParameterDefinition(name: "param4", label: "Smoothness", min: 0.1, max: 2, defaultValue: 1, uniformName: "blend_smooth")
            ]
        ),
        
        // PLASMA SHADER
        ShaderTemplate(
            name: "Plasma Effect",
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
                
                float t = u.time * u.param3; // speed control
                float freq = u.param1 * 10.0; // frequency
                float amp = u.param2; // amplitude
                
                float plasma = 0.0;
                plasma += sin(p.x * freq + t) * amp;
                plasma += sin(p.y * freq * 0.7 - t * 0.5) * amp;
                plasma += sin(length(p * freq * 0.5) - t * 2.0) * amp;
                plasma += cos(length(p - u.mouse * 2.0) * freq * 0.3 + t) * amp;
                plasma /= 4.0;
                
                float colorCycle = u.param4 * 6.28318;
                float3 color;
                color.r = sin(plasma * 3.14159 + colorCycle) * 0.5 + 0.5;
                color.g = sin(plasma * 3.14159 + colorCycle + 2.094) * 0.5 + 0.5;
                color.b = sin(plasma * 3.14159 + colorCycle + 4.189) * 0.5 + 0.5;
                
                return float4(color, 1.0);
            }
            """,
            parameters: [
                ParameterDefinition(name: "param1", label: "Frequency", min: 0.5, max: 3, defaultValue: 1, uniformName: "frequency"),
                ParameterDefinition(name: "param2", label: "Amplitude", min: 0.5, max: 2, defaultValue: 1, uniformName: "amplitude"),
                ParameterDefinition(name: "param3", label: "Speed", min: 0, max: 3, defaultValue: 1, uniformName: "speed"),
                ParameterDefinition(name: "param4", label: "Color Cycle", min: 0, max: 1, defaultValue: 0, uniformName: "color_cycle")
            ]
        ),
        
        // KALEIDOSCOPE SHADER
        ShaderTemplate(
            name: "Kaleidoscope",
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
                float param1; // segments
                float param2; // rotation_speed
                float param3; // zoom
                float param4; // color_blocks
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
            
            float hash(float2 p) {
                p = fract(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return fract(p.x * p.y);
            }
            
            fragment float4 fragmentShader(
                VertexOut in [[stage_in]],
                constant Uniforms& u [[buffer(0)]]
            ) {
                float2 p = (in.texCoord - 0.5) * 2.0 / u.param3; // zoom
                p.x *= u.resolution.x / u.resolution.y;
                
                // Kaleidoscope transformation
                float angle = atan2(p.y, p.x) + u.time * u.param2;
                float radius = length(p);
                
                float segments = floor(u.param1) * 2.0; // Number of segments (3-12)
                float segmentAngle = 2.0 * M_PI_F / segments;
                angle = fmod(angle, segmentAngle);
                
                if (int(atan2(p.y, p.x) / segmentAngle) % 2 == 1) {
                    angle = segmentAngle - angle;
                }
                
                float2 kp = radius * float2(cos(angle), sin(angle));
                
                // Color blocks
                float blockSize = u.param4 * 16.0;
                float2 blockUV = floor(kp * blockSize) / blockSize;
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
                
                // Add some variation
                float pulse = sin(radius * 10.0 - u.time * 3.0) * 0.5 + 0.5;
                color *= 0.7 + 0.3 * pulse;
                
                return float4(color, 1.0);
            }
            """,
            parameters: [
                ParameterDefinition(name: "param1", label: "Segments", min: 3, max: 12, defaultValue: 6, uniformName: "segments"),
                ParameterDefinition(name: "param2", label: "Rotation", min: -2, max: 2, defaultValue: 0.5, uniformName: "rotation_speed"),
                ParameterDefinition(name: "param3", label: "Zoom", min: 0.5, max: 3, defaultValue: 1, uniformName: "zoom"),
                ParameterDefinition(name: "param4", label: "Block Size", min: 0.5, max: 2, defaultValue: 1, uniformName: "color_blocks")
            ]
        ),
        
        // RIPPLE SHADER
        ShaderTemplate(
            name: "Water Ripple",
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
                float param1; // wave_count
                float param2; // wave_speed
                float param3; // damping
                float param4; // distortion
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
                float2 center = u.mouse;
                
                float dist = distance(uv, center);
                float waves = u.param1 * 50.0; // wave count
                float speed = u.param2 * 5.0; // wave speed
                
                float ripple = sin(dist * waves - u.time * speed);
                ripple *= exp(-dist * u.param3 * 5.0); // damping
                ripple = ripple * 0.5 + 0.5;
                
                // Distort UV coordinates
                float2 distortedUV = uv + ripple * u.param4 * 0.1 * normalize(uv - center);
                
                // Create water-like colors
                float3 deepWater = float3(0.0, 0.2, 0.4);
                float3 shallowWater = float3(0.3, 0.7, 0.9);
                float3 foam = float3(0.95, 0.98, 1.0);
                
                float3 color = mix(deepWater, shallowWater, ripple);
                color = mix(color, foam, pow(ripple, 3.0) * 0.8);
                
                // Add specular highlights
                float spec = pow(max(ripple, 0.0), 20.0);
                color += spec * 0.5;
                
                return float4(color, 1.0);
            }
            """,
            parameters: [
                ParameterDefinition(name: "param1", label: "Waves", min: 0.2, max: 2, defaultValue: 1, uniformName: "wave_count"),
                ParameterDefinition(name: "param2", label: "Speed", min: 0, max: 2, defaultValue: 1, uniformName: "wave_speed"),
                ParameterDefinition(name: "param3", label: "Damping", min: 0.2, max: 2, defaultValue: 0.6, uniformName: "damping"),
                ParameterDefinition(name: "param4", label: "Distortion", min: 0, max: 2, defaultValue: 0.5, uniformName: "distortion")
            ]
        ),
        
        // VORONOI SHADER
        ShaderTemplate(
            name: "Voronoi Cells",
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
                float param1; // cell_density
                float param2; // animation_speed
                float param3; // edge_sharpness
                float param4; // color_variance
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
            
            float2 hash2(float2 p) {
                p = float2(dot(p, float2(127.1, 311.7)),
                          dot(p, float2(269.5, 183.3)));
                return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
            }
            
            fragment float4 fragmentShader(
                VertexOut in [[stage_in]],
                constant Uniforms& u [[buffer(0)]]
            ) {
                float2 p = in.texCoord * u.param1 * 10.0; // cell density
                
                float2 i = floor(p);
                float2 f = fract(p);
                
                float minDist = 1.0;
                float2 minPoint;
                
                // Check neighboring cells
                for (int y = -1; y <= 1; y++) {
                    for (int x = -1; x <= 1; x++) {
                        float2 neighbor = float2(x, y);
                        float2 point = hash2(i + neighbor);
                        
                        // Animate points
                        point = 0.5 + 0.5 * sin(u.time * u.param2 + 6.2831 * point);
                        
                        float2 diff = neighbor + point - f;
                        float dist = length(diff);
                        
                        if (dist < minDist) {
                            minDist = dist;
                            minPoint = point;
                        }
                    }
                }
                
                // Edge detection
                float edge = 1.0 - smoothstep(0.0, u.param3 * 0.1, minDist);
                
                // Create colors based on cell position
                float3 cellColor = float3(
                    sin(minPoint.x * 12.9898 * u.param4),
                    sin(minPoint.y * 78.233 * u.param4),
                    sin((minPoint.x + minPoint.y) * 43.5453 * u.param4)
                ) * 0.5 + 0.5;
                
                float3 color = mix(cellColor, float3(1.0), edge * 0.3);
                
                return float4(color, 1.0);
            }
            """,
            parameters: [
                ParameterDefinition(name: "param1", label: "Cell Density", min: 0.5, max: 3, defaultValue: 1, uniformName: "cell_density"),
                ParameterDefinition(name: "param2", label: "Animation", min: 0, max: 2, defaultValue: 0.5, uniformName: "animation_speed"),
                ParameterDefinition(name: "param3", label: "Edge Sharp", min: 0.5, max: 3, defaultValue: 1, uniformName: "edge_sharpness"),
                ParameterDefinition(name: "param4", label: "Color Mix", min: 0.5, max: 3, defaultValue: 1, uniformName: "color_variance")
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
    var currentFPS: Double = 0
    private var lastFrameTime: CFTimeInterval = 0
    
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
        
        drawableSize = CGSize(width: 600, height: 400)
        
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
        let currentTime = CACurrentMediaTime()
        if lastFrameTime > 0 {
            let delta = currentTime - lastFrameTime
            currentFPS = 1.0 / delta
        }
        lastFrameTime = currentTime
        
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

// MARK: - Main App

class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var editorView: NSTextView!
    var previewView: MetalPreviewView!
    var statusLabel: NSTextField!
    var fpsLabel: NSTextField!
    var templatePopup: NSPopUpButton!
    
    var currentTemplate: ShaderTemplate?
    var parameterSliders: [NSSlider] = []
    var parameterLabels: [NSTextField] = []
    var parameterValueLabels: [NSTextField] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1200, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Studio Final - Professional Shader Development"
        
        setupUI()
        
        // Load first template
        selectTemplate(at: 0)
        
        window.makeKeyAndOrderFront(nil)
    }
    
    func setupUI() {
        let contentView = window.contentView!
        
        // LEFT SIDE - Editor
        setupEditor(in: contentView)
        
        // RIGHT SIDE - Preview and Controls
        setupPreviewAndControls(in: contentView)
        
        // BOTTOM - Controls
        setupBottomControls(in: contentView)
    }
    
    func setupEditor(in parent: NSView) {
        // Editor title
        let editorTitle = NSTextField(labelWithString: "Shader Code")
        editorTitle.frame = NSRect(x: 10, y: 670, width: 100, height: 20)
        editorTitle.font = .boldSystemFont(ofSize: 12)
        parent.addSubview(editorTitle)
        
        // Template selector
        templatePopup = NSPopUpButton(frame: NSRect(x: 120, y: 665, width: 200, height: 25))
        for template in ShaderLibrary.templates {
            templatePopup.addItem(withTitle: template.name)
        }
        templatePopup.target = self
        templatePopup.action = #selector(templateSelected)
        parent.addSubview(templatePopup)
        
        // Code editor
        let scrollView = NSScrollView(frame: NSRect(x: 10, y: 50, width: 580, height: 610))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        
        editorView = NSTextView(frame: scrollView.bounds)
        editorView.autoresizingMask = [.width, .height]
        editorView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
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
        let previewTitle = NSTextField(labelWithString: "Live Preview")
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
        
        // Parameter controls area
        let paramTitle = NSTextField(labelWithString: "Shader Parameters")
        paramTitle.frame = NSRect(x: 610, y: 220, width: 150, height: 20)
        paramTitle.font = .boldSystemFont(ofSize: 11)
        parent.addSubview(paramTitle)
        
        // Track mouse in preview
        let trackingArea = NSTrackingArea(
            rect: previewView.bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: previewView,
            userInfo: nil
        )
        previewView.addTrackingArea(trackingArea)
        
        // Update FPS
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.fpsLabel.stringValue = String(format: "FPS: %.0f", self.previewView.currentFPS)
            self.fpsLabel.textColor = self.previewView.currentFPS >= 55 ? .green : .orange
        }
    }
    
    func setupParameterControls(for template: ShaderTemplate) {
        // Clear existing controls
        parameterSliders.forEach { $0.removeFromSuperview() }
        parameterLabels.forEach { $0.removeFromSuperview() }
        parameterValueLabels.forEach { $0.removeFromSuperview() }
        parameterSliders.removeAll()
        parameterLabels.removeAll()
        parameterValueLabels.removeAll()
        
        var yPos: CGFloat = 180
        
        for (index, param) in template.parameters.enumerated() {
            // Label
            let label = NSTextField(labelWithString: param.label)
            label.frame = NSRect(x: 620, y: yPos, width: 100, height: 20)
            label.font = .systemFont(ofSize: 11)
            window.contentView?.addSubview(label)
            parameterLabels.append(label)
            
            // Slider
            let slider = NSSlider(value: Double(param.defaultValue), 
                                 minValue: Double(param.min), 
                                 maxValue: Double(param.max),
                                 target: self, 
                                 action: #selector(parameterChanged))
            slider.frame = NSRect(x: 720, y: yPos, width: 200, height: 20)
            slider.tag = index + 1
            window.contentView?.addSubview(slider)
            parameterSliders.append(slider)
            
            // Value label
            let valueLabel = NSTextField(labelWithString: String(format: "%.2f", param.defaultValue))
            valueLabel.frame = NSRect(x: 930, y: yPos, width: 50, height: 20)
            valueLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
            valueLabel.alignment = .right
            window.contentView?.addSubview(valueLabel)
            parameterValueLabels.append(valueLabel)
            
            // Set initial value
            updateUniformParam(index + 1, value: param.defaultValue)
            
            yPos -= 35
        }
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
        let exportButton = NSButton(title: "Export Swift", target: self, action: #selector(exportCode))
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
        let index = sender.tag - 1
        if index >= 0 && index < parameterValueLabels.count {
            let value = sender.floatValue
            parameterValueLabels[index].stringValue = String(format: "%.2f", value)
            updateUniformParam(sender.tag, value: value)
        }
    }
    
    func updateUniformParam(_ param: Int, value: Float) {
        switch param {
        case 1: previewView.uniforms.param1 = value
        case 2: previewView.uniforms.param2 = value
        case 3: previewView.uniforms.param3 = value
        case 4: previewView.uniforms.param4 = value
        case 5: previewView.uniforms.param5 = value
        case 6: previewView.uniforms.param6 = value
        case 7: previewView.uniforms.param7 = value
        case 8: previewView.uniforms.param8 = value
        default: break
        }
    }
    
    func selectTemplate(at index: Int) {
        guard index < ShaderLibrary.templates.count else { return }
        
        currentTemplate = ShaderLibrary.templates[index]
        editorView.string = currentTemplate!.source
        setupParameterControls(for: currentTemplate!)
        compileShader()
    }
    
    @objc func templateSelected(_ sender: NSPopUpButton) {
        selectTemplate(at: sender.indexOfSelectedItem)
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
        panel.nameFieldStringValue = "\(currentTemplate?.name ?? "shader").metal"
        panel.allowedContentTypes = [.plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? self.editorView.string.write(to: url, atomically: true, encoding: .utf8)
                self.statusLabel.stringValue = "✅ Saved: \(url.lastPathComponent)"
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
                    self.statusLabel.stringValue = "✅ Loaded: \(url.lastPathComponent)"
                }
            }
        }
    }
    
    @objc func exportCode() {
        let shaderName = currentTemplate?.name ?? "CustomShader"
        let className = shaderName.replacingOccurrences(of: " ", with: "")
        
        let swiftCode = """
        //
        //  \(className).swift
        //  Generated by Metal Studio Final
        //
        
        import Metal
        import MetalKit
        import simd
        
        class \(className) {
            private let device: MTLDevice
            private let pipelineState: MTLRenderPipelineState
            private let commandQueue: MTLCommandQueue
            
            struct Uniforms {
                var time: Float = 0
                var resolution: SIMD2<Float>
                var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
                var param1: Float = \(previewView.uniforms.param1)
                var param2: Float = \(previewView.uniforms.param2)
                var param3: Float = \(previewView.uniforms.param3)
                var param4: Float = \(previewView.uniforms.param4)
            }
            
            private var uniforms = Uniforms(resolution: SIMD2<Float>(1920, 1080))
            
            init(device: MTLDevice) throws {
                self.device = device
                self.commandQueue = device.makeCommandQueue()!
                
                let shaderSource = \"\"\"
        \(editorView.string)
        \"\"\"
                
                let library = try device.makeLibrary(source: shaderSource, options: nil)
                let vertexFunction = library.makeFunction(name: "vertexShader")!
                let fragmentFunction = library.makeFunction(name: "fragmentShader")!
                
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = vertexFunction
                pipelineDescriptor.fragmentFunction = fragmentFunction
                pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                
                self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            }
            
            func render(to view: MTKView) {
                guard let drawable = view.currentDrawable,
                      let descriptor = view.currentRenderPassDescriptor,
                      let commandBuffer = commandQueue.makeCommandBuffer(),
                      let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                    return
                }
                
                uniforms.time += 0.016 // Assuming 60fps
                uniforms.resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
                
                encoder.setRenderPipelineState(pipelineState)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
                
                commandBuffer.present(drawable)
                commandBuffer.commit()
            }
        }
        """
        
        // Save to file
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(className).swift"
        panel.allowedContentTypes = [.sourceCode]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? swiftCode.write(to: url, atomically: true, encoding: .utf8)
                self.statusLabel.stringValue = "✅ Exported Swift code: \(url.lastPathComponent)"
                self.statusLabel.textColor = .systemBlue
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

// Run the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()