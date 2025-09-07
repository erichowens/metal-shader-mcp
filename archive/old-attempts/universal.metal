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

// Hash function for pseudo-random values
float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Noise function
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

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    // Simplified kaleidoscope effect
    float2 center = float2(0.0);
    float angle = atan2(p.y, p.x) + u.time * 0.5;
    float radius = length(p);
    
    // 6 segments
    float segmentAngle = 2.0 * M_PI_F / 6.0;
    angle = fmod(angle, segmentAngle);
    
    // Mirror every other segment
    if (int(atan2(p.y, p.x) / segmentAngle) % 2 == 1) {
        angle = segmentAngle - angle;
    }
    
    // Convert back to cartesian
    float2 kp = radius * float2(cos(angle), sin(angle));
    
    // Create color blocks
    float2 blockUV = floor(kp * 8.0) / 8.0;
    float colorIndex = hash(blockUV + u.time * 0.1) * 4.0;
    
    float3 color;
    if (colorIndex < 1.0) {
        color = float3(1.0, 0.2, 0.2); // Red
    } else if (colorIndex < 2.0) {
        color = float3(0.2, 1.0, 0.2); // Green  
    } else if (colorIndex < 3.0) {
        color = float3(0.2, 0.4, 1.0); // Blue
    } else {
        color = float3(1.0, 0.9, 0.2); // Yellow
    }
    
    // Add some animation
    float pulse = sin(u.time * 2.0 + radius * 5.0) * 0.5 + 0.5;
    color *= 0.7 + 0.3 * pulse;
    
    // Mouse interaction
    float dist = length(p - (u.mouse - 0.5) * 2.0);
    float glow = exp(-dist * 3.0) * 0.5;
    color += glow;
    
    // Add some plasma overlay
    float plasma = sin(kp.x * 10.0 + u.time) * sin(kp.y * 10.0 - u.time);
    color = mix(color, float3(0.5, 0.3, 0.8), plasma * 0.2);
    
    return float4(color, 1.0);
}