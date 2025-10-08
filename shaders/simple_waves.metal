/**
 * Simple Waves
 * A basic animated wave pattern that works with the thumbnail renderer
 */

#include <metal_stdlib>
using namespace metal;

fragment float4 fragmentShader(float4 position [[position]]) {
    float2 uv = position.xy / 512.0; // Assuming 512x512 for thumbnails
    
    // Simple wave animation (using a fixed time for thumbnails)
    float time = 1.0;
    float wave1 = sin(uv.x * 10.0 + time * 2.0) * 0.5 + 0.5;
    float wave2 = sin(uv.y * 8.0 + time * 1.5) * 0.5 + 0.5;
    float wave3 = sin((uv.x + uv.y) * 6.0 + time) * 0.5 + 0.5;
    
    // Mix colors
    float3 color = float3(wave1, wave2, wave3) * 0.8 + 0.2;
    
    return float4(color, 1.0);
}