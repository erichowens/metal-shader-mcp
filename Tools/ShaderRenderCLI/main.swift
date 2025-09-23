import Foundation
import Metal
import MetalKit
import AppKit

// Simple headless renderer CLI
// Usage:
// swift run ShaderRenderCLI --shader-file path/to/shader.metal --out out.png [--width 256 --height 256 --time 0.0]

@main
struct ShaderRenderCLI {
    static func main() {
        let args = CommandLine.arguments
        var shaderFile: String? = nil
        var outPath: String = "render.png"
        var width = 256
        var height = 256
        var time: Float = 0.0

        var i = 1
        while i < args.count {
            let a = args[i]
            switch a {
            case "--shader-file": if i+1 < args.count { shaderFile = args[i+1]; i+=1 }
            case "--out": if i+1 < args.count { outPath = args[i+1]; i+=1 }
            case "--width": if i+1 < args.count, let v = Int(args[i+1]) { width = v; i+=1 }
            case "--height": if i+1 < args.count, let v = Int(args[i+1]) { height = v; i+=1 }
            case "--time": if i+1 < args.count, let v = Float(args[i+1]) { time = v; i+=1 }
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

        // Compile fragment function
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let fragment = library.makeFunction(name: "fragmentShader") else {
                fputs("[ShaderRenderCLI] fragmentShader not found\n", stderr)
                exit(2)
            }
            let vertex = try makeVertexFunction(device: device)
            let pdesc = MTLRenderPipelineDescriptor()
            pdesc.vertexFunction = vertex
            pdesc.fragmentFunction = fragment
            pdesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            let pipeline = try device.makeRenderPipelineState(descriptor: pdesc)

            // Output texture
            let tdesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            tdesc.usage = [.renderTarget, .shaderRead, .blit]
            guard let tex = device.makeTexture(descriptor: tdesc) else { fatalError("texture") }

            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture = tex
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].storeAction = .store
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

            guard let cb = commandQueue.makeCommandBuffer(),
                  let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { fatalError("enc") }
            enc.setRenderPipelineState(pipeline)

            // Uniforms
            var t = time
            var res = SIMD2<Float>(Float(width), Float(height))
            var mouse = SIMD2<Float>(0.0, 0.0)
            enc.setFragmentBytes(&t, length: MemoryLayout<Float>.size, index: 0)
            enc.setFragmentBytes(&res, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
            enc.setFragmentBytes(&mouse, length: MemoryLayout<SIMD2<Float>>.size, index: 2)

            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            enc.endEncoding()
            cb.commit()
            cb.waitUntilCompleted()

            try saveTexture(tex, to: outPath)
            print("[ShaderRenderCLI] Saved \(outPath) ("] + String(width) + "x" + String(height) + ")")
        } catch {
            fputs("[ShaderRenderCLI] Error: \(error)\n", stderr)
            exit(3)
        }
    }
}

private func makeVertexFunction(device: MTLDevice) throws -> MTLFunction {
    let src = """
    #include <metal_stdlib>
    using namespace metal;
    vertex float4 vertexShader(uint vid [[vertex_id]]) {
        float2 pos[4] = { float2(-1,-1), float2(1,-1), float2(-1,1), float2(1,1) };
        return float4(pos[vid], 0.0, 1.0);
    }
    """
    let lib = try device.makeLibrary(source: src, options: nil)
    guard let fn = lib.makeFunction(name: "vertexShader") else { throw NSError(domain: "vertex", code: -1) }
    return fn
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
fragment float4 fragmentShader(float4 pos [[position]], constant float &time [[buffer(0)]], constant float2 &resolution [[buffer(1)]], constant float2 &mouse [[buffer(2)]]) {
    float2 uv = pos.xy / resolution;
    float3 color = 0.5 + 0.5 * cos(time + uv.xyx + float3(0, 2, 4));
    return float4(color, 1.0);
}
"""
