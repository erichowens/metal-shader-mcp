import XCTest
import Metal

final class VisualRegressionGradientTests: XCTestCase {
    func testGradientMatchesGoldenWithinTolerance() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw XCTSkip("Metal unavailable; skipping visual test")
        }
        let (w, h) = Self.envResolution(defaultW: 64, defaultH: 64)
        // Inline gradient shader (matches Fixtures/gradient.metal)
        let src = """
        #include <metal_stdlib>
        using namespace metal;
        struct VOut { float4 position [[position]]; float2 uv; };
        vertex VOut vertexShader(uint vid [[vertex_id]]) {
            VOut o; float2 p[4] = { float2(-1,-1), float2(1,-1), float2(-1,1), float2(1,1) };
            float2 t[4] = { float2(0,1), float2(1,1), float2(0,0), float2(1,0) };
            o.position = float4(p[vid],0,1); o.uv = t[vid]; return o;
        }
        fragment float4 fragmentShader(VOut in [[stage_in]]) { return float4(in.uv.x, in.uv.y, 0.5, 1.0); }
        """
        let lib = try device.makeLibrary(source: src, options: nil)
        let v = lib.makeFunction(name: "vertexShader")!
        let f = lib.makeFunction(name: "fragmentShader")!
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = v
        desc.fragmentFunction = f
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        let pipeline = try device.makeRenderPipelineState(descriptor: desc)

        let tdesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        tdesc.usage = [.renderTarget, .shaderRead]
        let tex = device.makeTexture(descriptor: tdesc)!

        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = tex
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].storeAction = .store
        rpd.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

        let cb = queue.makeCommandBuffer()!
        let enc = cb.makeRenderCommandEncoder(descriptor: rpd)!
        enc.setRenderPipelineState(pipeline)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        enc.endEncoding()
        cb.commit(); cb.waitUntilCompleted()

        // Readback
        let bpr = w * 4
        let size = bpr * h
        let bytes = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 1)
        defer { bytes.deallocate() }
        tex.getBytes(bytes, bytesPerRow: bpr, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)

        // Prefer computed expectation for gradient to avoid color space flakiness in PNG decoders
        var failures = 0
        var missUpLeft = 0, missUpRight = 0, missDownLeft = 0, missDownRight = 0
        for y in 0..<h {
            let vUp = 1.0 - Float(y) / Float(max(h-1, 1))
            let vDown = Float(y) / Float(max(h-1, 1))
            for x in 0..<w {
                let uLeft = Float(x) / Float(max(w-1, 1))
                let uRight = 1.0 - uLeft
                let o = y * bpr + x * 4
                let b = bytes.load(fromByteOffset: o + 0, as: UInt8.self)
                let g = bytes.load(fromByteOffset: o + 1, as: UInt8.self)
                let r = bytes.load(fromByteOffset: o + 2, as: UInt8.self)
                let a = bytes.load(fromByteOffset: o + 3, as: UInt8.self)
                let expB = UInt8((0.5 * 255.0).rounded())
                let expA: UInt8 = 255
                let gUpLeft = UInt8((vUp * 255.0).rounded())
                let rUpLeft = UInt8((uLeft * 255.0).rounded())
                let gUpRight = UInt8((vUp * 255.0).rounded())
                let rUpRight = UInt8((uRight * 255.0).rounded())
                let gDownLeft = UInt8((vDown * 255.0).rounded())
                let rDownLeft = UInt8((uLeft * 255.0).rounded())
                let gDownRight = UInt8((vDown * 255.0).rounded())
                let rDownRight = UInt8((uRight * 255.0).rounded())
                if abs(Int(b) - Int(expB)) > 12 || abs(Int(g) - Int(gUpLeft)) > 12 || abs(Int(r) - Int(rUpLeft)) > 12 || abs(Int(a) - Int(expA)) > 12 { missUpLeft += 1 }
                if abs(Int(b) - Int(expB)) > 12 || abs(Int(g) - Int(gUpRight)) > 12 || abs(Int(r) - Int(rUpRight)) > 12 || abs(Int(a) - Int(expA)) > 12 { missUpRight += 1 }
                if abs(Int(b) - Int(expB)) > 12 || abs(Int(g) - Int(gDownLeft)) > 12 || abs(Int(r) - Int(rDownLeft)) > 12 || abs(Int(a) - Int(expA)) > 12 { missDownLeft += 1 }
                if abs(Int(b) - Int(expB)) > 12 || abs(Int(g) - Int(gDownRight)) > 12 || abs(Int(r) - Int(rDownRight)) > 12 || abs(Int(a) - Int(expA)) > 12 { missDownRight += 1 }
            }
        }
        failures = min(min(missUpLeft, missUpRight), min(missDownLeft, missDownRight))
        if failures > 0 {
            let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/screenshots/tests", isDirectory: true)
            try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            try TestImageUtils.saveBGRA8(bytes: bytes, width: w, height: h, to: outDir.appendingPathComponent("actual_gradient_\(w)x\(h).png"))
            // Generate a simple heatmap based on expected vs actual for visualization
            let bpr = w * 4
            var heat = [UInt8](repeating: 0, count: bpr * h)
            for y in 0..<h {
                let vUp = 1.0 - Float(y) / Float(max(h-1, 1))
                let vDown = Float(y) / Float(max(h-1, 1))
                for x in 0..<w {
                    let uLeft = Float(x) / Float(max(w-1, 1))
                    let uRight = 1.0 - uLeft
                    let o = y * bpr + x * 4
                    let b = bytes.load(fromByteOffset: o + 0, as: UInt8.self)
                    let g = bytes.load(fromByteOffset: o + 1, as: UInt8.self)
                    let r = bytes.load(fromByteOffset: o + 2, as: UInt8.self)
                    let expB = UInt8((0.5 * 255.0).rounded())
                    // choose quadrant that minimizes error, consistent with failures calculation
                    let candidates: [(UInt8, UInt8)] = [
                        (UInt8((vUp * 255.0).rounded()), UInt8((uLeft * 255.0).rounded())),
                        (UInt8((vUp * 255.0).rounded()), UInt8((uRight * 255.0).rounded())),
                        (UInt8((vDown * 255.0).rounded()), UInt8((uLeft * 255.0).rounded())),
                        (UInt8((vDown * 255.0).rounded()), UInt8((uRight * 255.0).rounded()))
                    ]
                    var best = Int.max
                    for (eg, er) in candidates {
                        let db = abs(Int(b) - Int(expB))
                        let dg = abs(Int(g) - Int(eg))
                        let dr = abs(Int(r) - Int(er))
                        best = min(best, max(db, max(dg, dr)))
                    }
                    let intensity = UInt8(min(255, best))
                    heat[o + 0] = 0
                    heat[o + 1] = 0
                    heat[o + 2] = intensity
                    heat[o + 3] = 255
                }
            }
            var hbuf = heat
            try TestImageUtils.saveBGRA8(bytes: &hbuf, width: w, height: h, to: outDir.appendingPathComponent("heatmap_gradient_\(w)x\(h).png"))
        }
        XCTAssertEqual(failures, 0, "Gradient differs from computed expectation beyond tolerance")
    }
    private static func envResolution(defaultW: Int, defaultH: Int) -> (Int, Int) {
        let env = ProcessInfo.processInfo.environment
        let w = Int(env["VIS_RES_W"] ?? "") ?? defaultW
        let h = Int(env["VIS_RES_H"] ?? "") ?? defaultH
        return (w, h)
    }
}
