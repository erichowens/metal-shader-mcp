#include <metal_stdlib>
using namespace metal;

// MARK: - Sparkle Effect Shader
// This shader creates magical sparkle effects for our whimsical UI buttons

struct SparkleVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex SparkleVertexOut sparkle_vertex(uint vertexID [[vertex_id]]) {
    SparkleVertexOut out;
    
    // Create a full-screen quad
    float2 positions[4] = {
        float2(-1.0, -1.0),  // Bottom-left
        float2( 1.0, -1.0),  // Bottom-right
        float2(-1.0,  1.0),  // Top-left
        float2( 1.0,  1.0)   // Top-right
    };
    
    float2 texCoords[4] = {
        float2(0.0, 1.0),    // Bottom-left
        float2(1.0, 1.0),    // Bottom-right
        float2(0.0, 0.0),    // Top-left
        float2(1.0, 0.0)     // Top-right
    };
    
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    
    return out;
}

fragment float4 sparkle_fragment(SparkleVertexOut in [[stage_in]],
                                constant float& phase [[buffer(0)]],
                                constant float& intensity [[buffer(1)]],
                                constant float& size [[buffer(2)]]) {
    
    float2 uv = in.texCoord;
    
    // Create multiple sparkle layers
    float sparkle = 0.0;
    
    // Layer 1: Large sparkles
    float2 grid1 = fract(uv * 8.0) - 0.5;
    float dist1 = length(grid1);
    float sparkle1 = smoothstep(0.0, size * 0.1, dist1) - smoothstep(size * 0.1, size * 0.2, dist1);
    sparkle1 *= sin(phase + dot(uv, float2(12.9898, 78.233)) * 10.0) * 0.5 + 0.5;
    
    // Layer 2: Medium sparkles
    float2 grid2 = fract(uv * 16.0) - 0.5;
    float dist2 = length(grid2);
    float sparkle2 = smoothstep(0.0, size * 0.05, dist2) - smoothstep(size * 0.05, size * 0.1, dist2);
    sparkle2 *= sin(phase * 1.5 + dot(uv, float2(23.9898, 45.233)) * 15.0) * 0.5 + 0.5;
    
    // Layer 3: Small sparkles
    float2 grid3 = fract(uv * 32.0) - 0.5;
    float dist3 = length(grid3);
    float sparkle3 = smoothstep(0.0, size * 0.025, dist3) - smoothstep(size * 0.025, size * 0.05, dist3);
    sparkle3 *= sin(phase * 2.0 + dot(uv, float2(34.9898, 67.233)) * 20.0) * 0.5 + 0.5;
    
    // Combine layers
    sparkle = sparkle1 + sparkle2 * 0.7 + sparkle3 * 0.5;
    
    // Apply intensity
    sparkle *= intensity;
    
    // Create color variation
    float3 color = float3(1.0, 0.9, 0.8); // Warm white sparkles
    color += float3(0.1, 0.2, 0.3) * sin(phase + uv.x * 10.0);
    
    return float4(color * sparkle, sparkle);
}

// MARK: - Confetti Effect Shader
// This shader creates confetti particles for magic moments

struct ConfettiVertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

vertex ConfettiVertexOut confetti_vertex(uint vertexID [[vertex_id]],
                                       constant float4x4& transform [[buffer(0)]],
                                       constant float4& color [[buffer(1)]]) {
    ConfettiVertexOut out;
    
    // Create a small quad for each confetti particle
    float2 positions[4] = {
        float2(-0.1, -0.1),
        float2( 0.1, -0.1),
        float2(-0.1,  0.1),
        float2( 0.1,  0.1)
    };
    
    float2 texCoords[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };
    
    float4 pos = float4(positions[vertexID], 0.0, 1.0);
    out.position = transform * pos;
    out.texCoord = texCoords[vertexID];
    out.color = color;
    
    return out;
}

fragment float4 confetti_fragment(ConfettiVertexOut in [[stage_in]]) {
    // Simple confetti particle
    float2 uv = in.texCoord;
    float alpha = 1.0 - smoothstep(0.0, 1.0, length(uv - 0.5) * 2.0);
    
    return float4(in.color.rgb, in.color.a * alpha);
}

// MARK: - Gradient Shader for Button Backgrounds
// This shader creates beautiful gradients for our whimsical buttons

fragment float4 gradient_fragment(SparkleVertexOut in [[stage_in]],
                                 constant float4& color1 [[buffer(0)]],
                                 constant float4& color2 [[buffer(1)]],
                                 constant float2& direction [[buffer(2)]]) {
    
    float2 uv = in.texCoord;
    
    // Create gradient based on direction
    float t = dot(uv, direction);
    t = smoothstep(0.0, 1.0, t);
    
    // Mix colors
    float4 color = mix(color1, color2, t);
    
    return color;
}

// MARK: - Glow Effect Shader
// This shader creates a subtle glow around elements

fragment float4 glow_fragment(SparkleVertexOut in [[stage_in]],
                             constant float& intensity [[buffer(0)]],
                             constant float& radius [[buffer(1)]]) {
    
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    
    float dist = length(uv - center);
    float glow = 1.0 - smoothstep(0.0, radius, dist);
    
    float3 color = float3(1.0, 1.0, 1.0) * glow * intensity;
    
    return float4(color, glow * intensity);
}
