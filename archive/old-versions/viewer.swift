#!/usr/bin/env swift

/**
 * Simple Metal Shader Viewer
 * Run with: swift viewer.swift
 */

import Cocoa
import Metal
import MetalKit

class ShaderView: MTKView {
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var startTime: Date = Date()
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        setup()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setup() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        colorPixelFormat = .bgra8Unorm
        
        // Load the compiled shader
        let shaderPath = "shaders/kaleidoscope.air"
        
        do {
            // Try to load pre-compiled shader
            let library = try device?.makeLibrary(filepath: shaderPath)
            
            // If that doesn't work, use inline shader
            if library == nil {
                let shaderCode = """
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
                
                fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
                    float2 uv = in.texCoord;
                    float time = 0.0;
                    
                    // Animated gradient with time
                    float3 color = float3(
                        sin(uv.x * 10.0 + time) * 0.5 + 0.5,
                        sin(uv.y * 10.0 + time * 1.3) * 0.5 + 0.5,
                        sin((uv.x + uv.y) * 10.0 + time * 0.7) * 0.5 + 0.5
                    );
                    
                    return float4(color, 1.0);
                }
                """
                
                let library = try device?.makeLibrary(source: shaderCode, options: nil)
                
                let vertexFunction = library?.makeFunction(name: "vertexShader")
                let fragmentFunction = library?.makeFunction(name: "fragmentShader")
                
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = vertexFunction
                pipelineDescriptor.fragmentFunction = fragmentFunction
                pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
                
                pipelineState = try device?.makeRenderPipelineState(descriptor: pipelineDescriptor)
            }
        } catch {
            print("Error setting up Metal: \(error)")
        }
        
        delegate = self
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

extension ShaderView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        draw(view.bounds)
    }
}

// Create window and run
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var metalView: ShaderView!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Shader Viewer"
        
        metalView = ShaderView(frame: window.contentView!.bounds)
        metalView.autoresizingMask = [.width, .height]
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        
        window.contentView?.addSubview(metalView)
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Run the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()