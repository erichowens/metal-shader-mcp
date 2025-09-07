/**
 * Kaleidoscope Shader Example
 * Creates prismatic effects with color blocks and geometric transformations
 * 
 * Performance target: 60fps on modern iOS/macOS devices
 */

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// Uniforms structure
struct Uniforms {
    float time;                  // Animation time (0-1)
    float2 resolution;           // Screen resolution
    float2 touchPoint;           // Touch position (normalized)
    float progress;              // Dissolve progress (0-1)
    int segments;                // Number of kaleidoscope segments
    float rotation;              // Rotation angle
    float zoom;                  // Zoom level
    float blockSize;             // Size of color blocks
    float noiseScale;            // Perlin noise scale
    float chromaticAberration;   // Chromatic aberration amount
};

// Vertex shader output
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Simple vertex shader for full-screen quad
vertex VertexOut vertexShader(
    uint vertexID [[vertex_id]]
) {
    VertexOut out;
    
    // Generate full-screen triangle strip
    float2 positions[4] = {
        float2(-1, -1),
        float2( 1, -1),
        float2(-1,  1),
        float2( 1,  1)
    };
    
    float2 texCoords[4] = {
        float2(0, 1),
        float2(1, 1),
        float2(0, 0),
        float2(1, 0)
    };
    
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = texCoords[vertexID];
    
    return out;
}

// Perlin noise functions
float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// Kaleidoscope transformation
float2 kaleidoscope(float2 uv, int segments, float rotation) {
    // Convert to polar coordinates
    float2 center = float2(0.5, 0.5);
    float2 p = uv - center;
    
    float angle = atan2(p.y, p.x) + rotation;
    float radius = length(p);
    
    // Create kaleidoscope segments
    float segmentAngle = 2.0 * M_PI_F / float(segments);
    angle = fmod(angle, segmentAngle);
    
    // Mirror every other segment
    if (fmod(floor(atan2(p.y, p.x) / segmentAngle), 2.0) == 1.0) {
        angle = segmentAngle - angle;
    }
    
    // Convert back to Cartesian
    return center + radius * float2(cos(angle), sin(angle));
}

// RGBY color block generation
float4 generateColorBlock(float2 uv, float blockSize, float noiseValue) {
    // Quantize UV to create blocks
    float2 blockUV = floor(uv * blockSize) / blockSize;
    
    // Generate pseudo-random color based on block position
    float colorIndex = hash(blockUV) * 4.0;
    
    // Primary color palette
    float4 colors[4] = {
        float4(1.0, 0.2, 0.2, 1.0),  // Red
        float4(0.2, 1.0, 0.2, 1.0),  // Green
        float4(0.2, 0.4, 1.0, 1.0),  // Blue
        float4(1.0, 0.9, 0.2, 1.0)   // Yellow
    };
    
    int index = int(colorIndex) % 4;
    float4 baseColor = colors[index];
    
    // Add noise variation
    baseColor.rgb += (noiseValue - 0.5) * 0.2;
    
    return baseColor;
}

// Breathing animation (0.4Hz as per spec)
float breathe(float time) {
    return 0.5 + 0.5 * sin(time * 2.0 * M_PI_F * 0.4);
}

// Main fragment shader
fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Apply kaleidoscope transformation
    float2 kaleidoUV = kaleidoscope(uv, uniforms.segments, uniforms.rotation);
    
    // Apply zoom
    kaleidoUV = (kaleidoUV - 0.5) / uniforms.zoom + 0.5;
    
    // Generate Perlin noise for organic dissolution
    float noiseValue = fbm(kaleidoUV * uniforms.noiseScale + uniforms.time * 0.5, 4);
    
    // Create dissolution threshold with breathing
    float breathingScale = breathe(uniforms.time);
    float dissolveThreshold = uniforms.progress * (1.0 + breathingScale * 0.1);
    
    // Sample input texture with chromatic aberration
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 rOffset = float2(uniforms.chromaticAberration, 0) * breathingScale;
    float2 gOffset = float2(0, 0);
    float2 bOffset = float2(-uniforms.chromaticAberration, 0) * breathingScale;
    
    float4 originalColor;
    originalColor.r = inputTexture.sample(textureSampler, kaleidoUV + rOffset).r;
    originalColor.g = inputTexture.sample(textureSampler, kaleidoUV + gOffset).g;
    originalColor.b = inputTexture.sample(textureSampler, kaleidoUV + bOffset).b;
    originalColor.a = 1.0;
    
    // Generate RGBY color blocks
    float4 blockColor = generateColorBlock(kaleidoUV, uniforms.blockSize, noiseValue);
    
    // Create smooth dissolution transition
    float dissolveMask = smoothstep(dissolveThreshold - 0.1, dissolveThreshold + 0.1, noiseValue);
    
    // Mix between original and block colors
    float4 finalColor = mix(blockColor, originalColor, dissolveMask);
    
    // Add touch interaction ripple
    float touchDist = length(uv - uniforms.touchPoint);
    float ripple = sin(touchDist * 20.0 - uniforms.time * 10.0) * 0.5 + 0.5;
    ripple *= exp(-touchDist * 3.0);
    finalColor.rgb += ripple * 0.1;
    
    // Apply final color grading
    finalColor.rgb = pow(finalColor.rgb, float3(0.95)); // Slight gamma correction
    
    return finalColor;
}

// Simplified fragment shader for performance testing
fragment float4 fragmentShaderSimple(
    VertexOut in [[stage_in]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Simple kaleidoscope without texture sampling
    float2 kaleidoUV = kaleidoscope(uv, 6, uniforms.time);
    
    // Generate color blocks
    float4 color = generateColorBlock(kaleidoUV, 16.0, uniforms.time);
    
    return color;
}