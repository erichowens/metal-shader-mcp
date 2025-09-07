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
    float2 p = (uv - 0.5) * 2.0 / u.zoom;
    p.x *= u.resolution.x / u.resolution.y;
    
    // Animated gradient with parameters
    float3 color = float3(0.0);
    
    // Create animated pattern
    float pattern = sin(p.x * 10.0 * u.complexity + u.time * u.speed) * 
                   cos(p.y * 10.0 * u.complexity - u.time * u.speed * 0.7);
    
    // Apply color shift
    color.r = pattern * 0.5 + 0.5;
    color.g = (pattern * 0.5 + 0.5) * (1.0 - u.colorShift) + u.colorShift * 0.5;
    color.b = 1.0 - (pattern * 0.5 + 0.5) * u.colorShift;
    
    // Apply intensity
    color *= u.intensity;
    
    // Add mouse interaction
    float dist = length(p - (u.mouse - 0.5) * 2.0);
    float glow = exp(-dist * 3.0) * 0.5;
    color += glow;
    
    return float4(color, 1.0);
}