#include <metal_stdlib>
using namespace metal;

fragment float4 fragmentShader(float4 position [[position]],
                              constant float &time [[buffer(0)]],
                              constant float2 &resolution [[buffer(1)]]) {
    float2 uv = position.xy / resolution;
    
    // Simple animated gradient
    float3 color = 0.5 + 0.5 * cos(time + uv.xyx + float3(0, 2, 4));
    
    return float4(color, 1.0);
}