import Foundation
import Metal
import MetalKit
import AppKit

struct Uniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var mouse: SIMD2<Float>
    var complexity: Float
    var colorShift: Float
}

@main
struct ShaderRenderCLI {
    static func main() {
        let args = CommandLine.arguments
        var shaderFile: String? = nil
        var outPath: String = "render.png"
        var width = 256
        var height = 256
        var time: Float = 0.0
        var complexity: Float = 0.5
        var colorShift: Float = 0.0

        var i = 1
        while i < args.count {
            let a = args[i]
            switch a {
            case "--shader-file": if i+1 < args.count { shaderFile = args[i+1]; i+=1 }
            case "--out": if i+1 < args.count { outPath = args[i+1]; i+=1 }
            case "--width": if i+1 < args.count, let v = Int(args[i+1]) { width = v; i+=1 }
            case "--height": if i+1 < args.count, let v = Int(args[i+1]) { height = v; i+=1 }
            case "--time": if i+1 < args.count, let v = Float(args[i+1]) { time = v; i+=1 }
            case "--complexity": if i+1 < args.count, let v = Float(args[i+1]) { complexity = v; i+=1 }
            case "--colorShift": if i+1 < args.count, let v = Float(args[i+1]) { colorShift = v; i+=1 }
            default: break
            }
            i += 1
        }

        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else {
            fputs("[ShaderRenderCLI] No Metal device available\n", stderr)
            exit(1)
        }

        let shaderSource: String
        if let path = shaderFile, FileManager.default.fileExists(atPath: path) {
            shaderSource = (try? String(contentsOfFile: path)) ?? defaultShader
        } else {
            shaderSource = defaultShader
        }

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let fragment = library.makeFunction(name: "fragmentShader") else {
                fputs("[ShaderRenderCLI] fragmentShader not found\n", stderr)
                exit(2)
            }
            guard let vertex = library.makeFunction(name: "vertexShader") else {
                fputs("[ShaderRenderCLI] vertexShader not found\n", stderr)
                exit(2)
            }
            let pdesc = MTLRenderPipelineDescriptor()
            pdesc.vertexFunction = vertex
            pdesc.fragmentFunction = fragment
            pdesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            let pipeline = try device.makeRenderPipelineState(descriptor: pdesc)

            let tdesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            tdesc.usage = [.renderTarget, .shaderRead]
            guard let tex = device.makeTexture(descriptor: tdesc) else { fatalError("texture") }

            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture = tex
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].storeAction = .store
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

            guard let cb = commandQueue.makeCommandBuffer(),
                  let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { fatalError("enc") }
            enc.setRenderPipelineState(pipeline)

            var uniforms = Uniforms(
                time: time,
                resolution: SIMD2<Float>(Float(width), Float(height)),
                mouse: SIMD2<Float>(0.0, 0.0),
                complexity: complexity,
                colorShift: colorShift
            )
            enc.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 0)

            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            enc.endEncoding()
            cb.commit()
            cb.waitUntilCompleted()

            try saveTexture(tex, to: outPath)
            print("[ShaderRenderCLI] Saved \(outPath) (\(width)x\(height))")
        } catch {
            fputs("[ShaderRenderCLI] Error: \(error)\n", stderr)
            exit(3)
        }
    }
}

private func saveTexture(_ texture: MTLTexture, to path: String) throws {
    let width = texture.width
    let height = texture.height
    let bpr = width * 4
    let size = bpr * height
    let bytes = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 1)
    defer { bytes.deallocate() }
    texture.getBytes(bytes, bytesPerRow: bpr, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bmpInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
    guard let dp = CGDataProvider(dataInfo: nil, data: bytes, size: size, releaseData: {_,_,_ in}),
          let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bpr, space: colorSpace, bitmapInfo: bmpInfo, provider: dp, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
        throw NSError(domain: "image", code: -2)
    }
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, cg, nil)
    if !CGImageDestinationFinalize(dest) { throw NSError(domain: "write", code: -3) }
}

private let defaultShader = """
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

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float complexity;
    float colorShift;
};

fragment float4 fragmentShader(VertexOut in [[stage_in]], constant Uniforms& uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float3 color = 0.5 + 0.5 * cos(uniforms.time + uv.xyx + float3(0, 2, 4));
    return float4(color, 1.0);
}
"""
