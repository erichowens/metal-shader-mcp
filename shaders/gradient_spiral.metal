/**
 * Gradient Spiral
 * A colorful spiral gradient that works with the thumbnail renderer
 */

#include <metal_stdlib>
using namespace metal;

fragment float4 fragmentShader(float4 position [[position]]) {
    float2 uv = position.xy / 512.0; // Assuming 512x512 for thumbnails
    float2 center = float2(0.5, 0.5);
    float2 pos = uv - center;
    
    // Create spiral effect
    float angle = atan2(pos.y, pos.x);
    float radius = length(pos);
    float spiral = angle + radius * 8.0;
    
    // Create rainbow colors
    float3 color;
    color.r = sin(spiral + 0.0) * 0.5 + 0.5;
    color.g = sin(spiral + 2.1) * 0.5 + 0.5;
    color.b = sin(spiral + 4.2) * 0.5 + 0.5;
    
    // Add some brightness variation based on radius
    color *= (1.0 - radius * 0.5);
    
    return float4(color, 1.0);
}