import Metal
import MetalKit

// Test if Metal shaders compile at all
let device = MTLCreateSystemDefaultDevice()!
let shaderCode = """
#include <metal_stdlib>
using namespace metal;

vertex float4 vertexShader(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-0.5, -0.5),
        float2( 0.5, -0.5),
        float2( 0.0,  0.5)
    };
    return float4(positions[vertexID], 0.0, 1.0);
}

fragment float4 fragmentShader() {
    return float4(1.0, 0.0, 0.0, 1.0); // Red
}
"""

do {
    let library = try device.makeLibrary(source: shaderCode, options: nil)
    print("✓ Shader compilation works")
    
    if let vertex = library.makeFunction(name: "vertexShader"),
       let fragment = library.makeFunction(name: "fragmentShader") {
        print("✓ Functions found")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertex
        pipelineDescriptor.fragmentFunction = fragment
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let pipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        print("✓ Pipeline created successfully")
    }
} catch {
    print("✗ Error: \(error)")
}
