#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 positions[4] = {
        float2(-1, -1), float2(1, -1),
        float2(-1,  1), float2(1,  1)
    };
    out.position = float4(positions[vertexID], 0, 1);
    return out;
}

fragment float4 fragmentShader() {
    return float4(0.1, 0.2, 0.3, 1.0);
}
