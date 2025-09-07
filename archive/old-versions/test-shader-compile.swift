#!/usr/bin/env swift

import Metal

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

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Simple gradient
    float3 color = float3(uv.x, uv.y, 0.5);
    
    return float4(color, 1.0);
}
"""

if let device = MTLCreateSystemDefaultDevice() {
    print("Testing shader compilation...")
    
    do {
        let library = try device.makeLibrary(source: shaderCode, options: nil)
        print("✅ Shader compiled successfully!")
        
        if let vertexFunc = library.makeFunction(name: "vertexShader"),
           let fragmentFunc = library.makeFunction(name: "fragmentShader") {
            print("✅ Found vertex and fragment functions")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunc
            pipelineDescriptor.fragmentFunction = fragmentFunc
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            let _ = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("✅ Pipeline state created successfully!")
        }
    } catch {
        print("❌ Error: \(error)")
    }
} else {
    print("❌ Metal not available")
}