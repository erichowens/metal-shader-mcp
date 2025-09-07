/**
 * Advanced Plasma Fractal Shader
 * Combines fractal mathematics with plasma effects for stunning visuals
 */

#include <metal_stdlib>
#include <simd/simd.h>
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
    float colorShift;
};

// Vertex shader
vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 positions[4] = {
        float2(-1, -1), float2(1, -1),
        float2(-1, 1), float2(1, 1)
    };
    float2 texCoords[4] = {
        float2(0, 1), float2(1, 1),
        float2(0, 0), float2(1, 0)
    };
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = texCoords[vertexID];
    return out;
}

// Complex number operations for fractals
float2 complexMul(float2 a, float2 b) {
    return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

float2 complexDiv(float2 a, float2 b) {
    float denominator = dot(b, b);
    return float2(
        (a.x * b.x + a.y * b.y) / denominator,
        (a.y * b.x - a.x * b.y) / denominator
    );
}

// Smooth noise function
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = fract(sin(dot(i, float2(12.9898, 78.233))) * 43758.5453);
    float b = fract(sin(dot(i + float2(1, 0), float2(12.9898, 78.233))) * 43758.5453);
    float c = fract(sin(dot(i + float2(0, 1), float2(12.9898, 78.233))) * 43758.5453);
    float d = fract(sin(dot(i + float2(1, 1), float2(12.9898, 78.233))) * 43758.5453);
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal brownian motion
float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float lacunarity = 2.1;
    float gain = 0.47;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= gain;
        frequency *= lacunarity;
        p = p * 2.0 + float2(1.17, 0.31);
    }
    
    return value;
}

// Julia set fractal
float julia(float2 z, float2 c, int iterations) {
    float n = 0.0;
    for (int i = 0; i < iterations; i++) {
        if (length(z) > 2.0) break;
        z = complexMul(z, z) + c;
        n++;
    }
    return n / float(iterations);
}

// Mandelbrot-inspired pattern
float mandelbrotPattern(float2 p, float time) {
    float2 c = p;
    float2 z = float2(0.0);
    
    // Animate the constant
    c += float2(sin(time * 0.1), cos(time * 0.13)) * 0.1;
    
    float iter = 0.0;
    for (int i = 0; i < 64; i++) {
        z = complexMul(z, z) + c;
        if (dot(z, z) > 4.0) {
            iter = float(i) / 64.0;
            break;
        }
    }
    
    // Smooth iteration count
    if (iter > 0.0) {
        float log_zn = log(dot(z, z)) / 2.0;
        float nu = log(log_zn / log(2.0)) / log(2.0);
        iter = iter + 1.0 - nu;
    }
    
    return iter;
}

// Plasma effect
float plasma(float2 p, float time) {
    float value = 0.0;
    
    value += sin(p.x * 8.0 + time * 2.0);
    value += sin(p.y * 6.0 + time * 1.5);
    value += sin((p.x + p.y) * 4.0 + time);
    value += sin(sqrt(p.x * p.x + p.y * p.y) * 8.0 - time);
    value += sin(p.x * sin(time / 2.0) * 4.0) * 2.0;
    value += sin(p.y * sin(time / 3.0) * 3.0) * 2.0;
    
    // Add fractal noise
    value += fbm(p * 3.0 + time * 0.5, 4) * 2.0;
    
    return value / 8.0;
}

// Vortex distortion
float2 vortex(float2 p, float2 center, float strength, float time) {
    float2 offset = p - center;
    float distance = length(offset);
    float angle = atan2(offset.y, offset.x);
    
    angle += strength * exp(-distance * 3.0) * sin(time);
    
    return center + distance * float2(cos(angle), sin(angle));
}

// Color palette generation
float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

// Main fragment shader
fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float time = uniforms.time;
    
    // Apply vortex distortion
    float2 vortexCenter = uniforms.mouse - 0.5;
    p = vortex(p, vortexCenter, 2.0, time);
    
    // Layer 1: Mandelbrot pattern
    float mandel = mandelbrotPattern(p * 2.0, time * 0.1);
    
    // Layer 2: Julia set
    float2 juliaC = float2(
        sin(time * 0.2) * 0.4,
        cos(time * 0.3) * 0.4
    );
    float juliaValue = julia(p * 1.5, juliaC, 128);
    
    // Layer 3: Plasma
    float plasmaValue = plasma(p, time);
    
    // Layer 4: Fractal noise
    float noiseValue = fbm(p * 4.0 + time * 0.2, 5);
    
    // Combine layers
    float finalValue = 0.0;
    finalValue += mandel * 0.3;
    finalValue += juliaValue * 0.3;
    finalValue += plasmaValue * 0.2;
    finalValue += noiseValue * 0.2;
    
    // Generate colors using multiple palettes
    float3 color1 = palette(
        finalValue + uniforms.colorShift,
        float3(0.5, 0.5, 0.5),
        float3(0.5, 0.5, 0.5),
        float3(1.0, 1.0, 1.0),
        float3(0.0, 0.10, 0.20)
    );
    
    float3 color2 = palette(
        finalValue * 1.5 + time * 0.1,
        float3(0.8, 0.5, 0.4),
        float3(0.2, 0.4, 0.2),
        float3(2.0, 1.0, 1.0),
        float3(0.0, 0.25, 0.25)
    );
    
    float3 color3 = palette(
        juliaValue + plasmaValue,
        float3(0.5, 0.5, 0.0),
        float3(0.5, 0.5, 0.0),
        float3(1.0, 1.0, 0.0),
        float3(0.0, 0.33, 0.67)
    );
    
    // Mix colors based on pattern values
    float3 finalColor = mix(color1, color2, juliaValue);
    finalColor = mix(finalColor, color3, sin(plasmaValue * 3.14159) * 0.5 + 0.5);
    
    // Add glow effect
    float glow = exp(-length(p) * 0.5) * 0.3;
    finalColor += float3(glow * 0.5, glow * 0.7, glow);
    
    // Add shimmer
    float shimmer = sin(finalValue * 20.0 + time * 10.0) * 0.05 + 0.95;
    finalColor *= shimmer;
    
    // Tone mapping
    finalColor = finalColor / (finalColor + float3(1.0));
    finalColor = pow(finalColor, float3(0.85));
    
    return float4(finalColor, 1.0);
}

// Performance-optimized version
fragment float4 fragmentShaderFast(
    VertexOut in [[stage_in]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    float time = uniforms.time;
    
    // Simplified plasma
    float value = 0.0;
    value += sin(p.x * 8.0 + time * 2.0);
    value += sin(p.y * 6.0 + time * 1.5);
    value += sin(length(p) * 8.0 - time);
    value *= 0.5;
    
    // Simple color palette
    float3 color = float3(
        sin(value * 3.14159 + 0.0) * 0.5 + 0.5,
        sin(value * 3.14159 + 2.09) * 0.5 + 0.5,
        sin(value * 3.14159 + 4.18) * 0.5 + 0.5
    );
    
    return float4(color, 1.0);
}