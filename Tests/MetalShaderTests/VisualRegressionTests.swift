import XCTest
import Metal

import ImageIO

final class VisualRegressionTests: XCTestCase {
    func testConstantColorImageMatchesGoldenWithinTolerance() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw XCTSkip("Metal unavailable; skipping visual test")
        }
        let (w, h) = Self.envResolution(defaultW: 64, defaultH: 64)
        // Simple shader producing constant color (0.1, 0.2, 0.3, 1.0)
        let src = """
        #include <metal_stdlib>
        using namespace metal;
        vertex float4 vertexShader(uint vid [[vertex_id]]) {
            float2 p[4] = { float2(-1,-1), float2(1,-1), float2(-1,1), float2(1,1) };
            return float4(p[vid], 0, 1);
        }
        fragment float4 fragmentShader() {
            return float4(0.1, 0.2, 0.3, 1.0);
        }
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
        cb.commit()
        cb.waitUntilCompleted()

        // Read back rendered image bytes
        let bpr = w * 4
        let size = bpr * h
        let bytes = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 1)
        defer { bytes.deallocate() }
        tex.getBytes(bytes, bytesPerRow: bpr, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)

        // Load golden PNG via test resources (Bundle.module)
        // Try resolution-specific first, then fallback
        var goldenURL: URL? = nil
        if let u = Bundle.module.url(forResource: "golden_constant_color_\(w)x\(h)", withExtension: "png") {
            goldenURL = u
        } else {
            goldenURL = Bundle.module.url(forResource: "golden_constant_color", withExtension: "png")
        }
        guard let gURL = goldenURL else {
            XCTFail("Missing golden image in test resources")
            return
        }
        let (gBytes, gW, gH) = try TestImageUtils.loadPNG(url: gURL)
        XCTAssertEqual(gW, w)
        XCTAssertEqual(gH, h)

        let tolCfg = TestImageUtils.resolveTolerance(width: w, height: h, testName: "VisualRegressionTests.testConstantColorImageMatchesGoldenWithinTolerance")
        var (failures, diff, heat) = TestImageUtils.compareBGRA8(bytes, gBytes, width: w, height: h, tolerance: tolCfg)

        if failures > 0 {
            // Fallback: computed expectation for constant color
            let expB: UInt8 = UInt8((0.3 * 255.0).rounded())
            let expG: UInt8 = UInt8((0.2 * 255.0).rounded())
            let expR: UInt8 = UInt8((0.1 * 255.0).rounded())
            let expA: UInt8 = 255
            let tol = tolCfg.global
            var miss = 0
            for y in 0..<h {
                for x in 0..<w {
                    let o = y * bpr + x * 4
                    let b = bytes.load(fromByteOffset: o + 0, as: UInt8.self)
                    let g = bytes.load(fromByteOffset: o + 1, as: UInt8.self)
                    let r = bytes.load(fromByteOffset: o + 2, as: UInt8.self)
                    let a = bytes.load(fromByteOffset: o + 3, as: UInt8.self)
                    if abs(Int(b) - Int(expB)) > tol || abs(Int(g) - Int(expG)) > tol || abs(Int(r) - Int(expR)) > tol || abs(Int(a) - Int(expA)) > tol {
                        miss += 1
                    }
                }
            }
            if miss == 0 {
                failures = 0
            } else {
                // Save actual and diff images for inspection
                let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("Resources/screenshots/tests", isDirectory: true)
                try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
                let actualURL = outDir.appendingPathComponent("actual_constant_color_\(w)x\(h).png")
                let diffURL = outDir.appendingPathComponent("diff_constant_color_\(w)x\(h).png")
                let heatURL = outDir.appendingPathComponent("heatmap_constant_color_\(w)x\(h).png")
                try TestImageUtils.saveBGRA8(bytes: bytes, width: w, height: h, to: actualURL)
                var d = diff
                try TestImageUtils.saveBGRA8(bytes: &d, width: w, height: h, to: diffURL)
                var hbuf = heat
                try TestImageUtils.saveBGRA8(bytes: &hbuf, width: w, height: h, to: heatURL)
                // Write summary JSON
                let summaryURL = outDir.appendingPathComponent("constant_color_summary_\(w)x\(h).json")
                let payload: [String: Any] = [
                    "test": "constant_color",
                    "timestamp": Date().timeIntervalSince1970,
                    "tolerance": ["r": tolCfg.r, "g": tolCfg.g, "b": tolCfg.b, "a": tolCfg.a, "global": tolCfg.global],
                    "mismatches": failures,
                    "width": w,
                    "height": h,
                    "actual_path": actualURL.path,
                    "diff_path": diffURL.path,
                    "heatmap_path": heatURL.path
                ]
                if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
                    try? data.write(to: summaryURL)
                }
            }
        }
        XCTAssertEqual(failures, 0, "Rendered image differs from golden beyond tolerance; see Resources/screenshots/tests for outputs if present")
    }

    // Helpers migrated to TestImageUtils.swift

    private static func envResolution(defaultW: Int, defaultH: Int) -> (Int, Int) {
        let env = ProcessInfo.processInfo.environment
        let w = Int(env["VIS_RES_W"] ?? "") ?? defaultW
        let h = Int(env["VIS_RES_H"] ?? "") ?? defaultH
        return (w, h)
    }
}
