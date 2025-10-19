import SwiftUI
import MetalKit
import Metal
import QuartzCore

final class MetalShaderRenderer: ObservableObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    @Published var fps: Double = 0
    private var pipelineState: MTLRenderPipelineState?
    private var startTime = CACurrentMediaTime()
    
    init() {
        guard let d = MTLCreateSystemDefaultDevice(), let q = d.makeCommandQueue() else {
            fatalError("Metal is unavailable on this machine")
        }
        device = d
        commandQueue = q
        updateShader(Self.defaultShader, onError: nil)
    }
    
    func updateShader(_ source: String, onError: ((String?) -> Void)? = nil) {
        do {
            let fragLib = try device.makeLibrary(source: source, options: nil)
            guard let fragment = fragLib.makeFunction(name: "fragmentShader") else {
                onError?("Missing fragmentShader entry point")
                return
            }
            let vertexLib = try device.makeLibrary(source: Self.vertexSource, options: nil)
            guard let vertex = vertexLib.makeFunction(name: "passthroughVertex") else {
                onError?("Failed to create vertex function")
                return
            }
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertex
            desc.fragmentFunction = fragment
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineState = try device.makeRenderPipelineState(descriptor: desc)
            onError?(nil)
        } catch {
            onError?(error.localizedDescription)
        }
    }
    
    fileprivate func render(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let rp = view.currentRenderPassDescriptor,
              let ps = pipelineState,
              let cb = commandQueue.makeCommandBuffer(),
              let enc = cb.makeRenderCommandEncoder(descriptor: rp) else {
            return
        }
        enc.setRenderPipelineState(ps)
        var t = Float(CACurrentMediaTime() - startTime)
        var res = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        enc.setFragmentBytes(&t, length: MemoryLayout<Float>.size, index: 0)
        enc.setFragmentBytes(&res, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        enc.endEncoding()
        cb.addCompletedHandler { _ in DispatchQueue.main.async { self.fps = 60 } }
        cb.present(drawable)
        cb.commit()
    }
    
    static let vertexSource = """
    #include <metal_stdlib>
    using namespace metal;
    vertex float4 passthroughVertex(uint vid [[vertex_id]]) {
        float2 p[4] = { float2(-1,-1), float2(1,-1), float2(-1,1), float2(1,1) };
        return float4(p[vid], 0, 1);
    }
    """
    
    static let defaultShader = """
    #include <metal_stdlib>
    using namespace metal;
    fragment float4 fragmentShader(float4 position [[position]],
                                  constant float &time [[buffer(0)]],
                                  constant float2 &resolution [[buffer(1)]]) {
        float2 uv = position.xy / resolution;
        float3 color = 0.5 + 0.5 * cos(time + uv.xyx + float3(0,2,4));
        return float4(color, 1.0);
    }
    """
}

struct MetalView: NSViewRepresentable {
    let renderer: MetalShaderRenderer
    func makeNSView(context: Context) -> MTKView {
        let v = MTKView()
        v.device = MTLCreateSystemDefaultDevice()
        v.colorPixelFormat = .bgra8Unorm
        v.preferredFramesPerSecond = 60
        v.enableSetNeedsDisplay = false
        v.isPaused = false
        v.delegate = context.coordinator
        return v
    }
    func updateNSView(_ nsView: MTKView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(renderer) }
    final class Coordinator: NSObject, MTKViewDelegate {
        let renderer: MetalShaderRenderer
        init(_ r: MetalShaderRenderer) { self.renderer = r }
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        func draw(in view: MTKView) { renderer.render(in: view) }
    }
}
