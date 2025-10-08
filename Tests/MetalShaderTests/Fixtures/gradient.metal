#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 positions[4] = {
        float2(-1, -1), float2(1, -1),
        float2(-1,  1), float2(1,  1)
    };
    float2 tex[4] = {
        float2(0, 1), float2(1, 1),
        float2(0, 0), float2(1, 0)
    };
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = tex[vertexID];
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    // simple x,y gradient into RGB
    return float4(in.texCoord.x, in.texCoord.y, 0.5, 1.0);
}
