import XCTest
import Foundation
import Metal
@testable import MetalShaderCore

struct ChannelTolerance {
    var r: Int
    var g: Int
    var b: Int
    var a: Int
    var global: Int
}

final class TestImageUtils {
    // MARK: - PNG IO
    static func loadPNG(url: URL) throws -> ([UInt8], Int, Int) {
        let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
        guard let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { throw NSError(domain: "png", code: -1) }
        let w = img.width
        let h = img.height
        let bpr = w * 4
        var buf = [UInt8](repeating: 0, count: bpr * h)
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (buf, w, h)
    }

    static func saveBGRA8(bytes: UnsafeMutableRawPointer, width: Int, height: Int, to url: URL) throws {
        let bpr = width * 4
        let cs = CGColorSpaceCreateDeviceRGB()
        let bmp = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        let dp = CGDataProvider(dataInfo: nil, data: bytes, size: bpr * height, releaseData: {_,_,_ in})!
        guard let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bpr, space: cs, bitmapInfo: bmp, provider: dp, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw NSError(domain: "img", code: -2)
        }
        let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cg, nil)
        if !CGImageDestinationFinalize(dest) { throw NSError(domain: "write", code: -3) }
    }

    // MARK: - Diffing
    static func compareBGRA8(_ a: UnsafeMutableRawPointer, _ b: [UInt8], width: Int, height: Int, tolerance: Int) -> (failures: Int, diff: [UInt8]) {
        let tol = ChannelTolerance(r: tolerance, g: tolerance, b: tolerance, a: tolerance, global: tolerance)
        let result = compareBGRA8(a, b, width: width, height: height, tolerance: tol)
        return (result.failures, result.diff)
    }

    static func compareBGRA8(_ a: UnsafeMutableRawPointer, _ b: [UInt8], width: Int, height: Int, tolerance: ChannelTolerance) -> (failures: Int, diff: [UInt8], heatmap: [UInt8]) {
        let bpr = width * 4
        var failures = 0
        var diff = [UInt8](repeating: 0, count: bpr * height)
        var heat = [UInt8](repeating: 0, count: bpr * height)
        for y in 0..<height {
            for x in 0..<width {
                let o = y * bpr + x * 4
                let ab = a.load(fromByteOffset: o + 0, as: UInt8.self)
                let ag = a.load(fromByteOffset: o + 1, as: UInt8.self)
                let ar = a.load(fromByteOffset: o + 2, as: UInt8.self)
                let aa = a.load(fromByteOffset: o + 3, as: UInt8.self)

                let bb = b[o + 0]
                let bg = b[o + 1]
                let br = b[o + 2]
                let ba = b[o + 3]

                let db = abs(Int(ab) - Int(bb))
                let dg = abs(Int(ag) - Int(bg))
                let dr = abs(Int(ar) - Int(br))
                let da = abs(Int(aa) - Int(ba))

                // Per-channel tolerance, then fallback to global
                var bad = (db > max(tolerance.b, tolerance.global) ||
                           dg > max(tolerance.g, tolerance.global) ||
                           dr > max(tolerance.r, tolerance.global) ||
                           da > max(tolerance.a, tolerance.global))
                if bad {
                    // try swapped R/B (common BGRA/RGBA confusion)
                    let drb = abs(Int(ar) - Int(bb))
                    let dbr = abs(Int(ab) - Int(br))
                    bad = (dbr > max(tolerance.b, tolerance.global) ||
                           dg  > max(tolerance.g, tolerance.global) ||
                           drb > max(tolerance.r, tolerance.global) ||
                           da  > max(tolerance.a, tolerance.global))
                }
                if bad { failures += 1 }
                // Diff mask output: pass golden where OK, highlight red where bad
                diff[o + 0] = bad ? 0 : bb
                diff[o + 1] = bad ? 0 : bg
                diff[o + 2] = bad ? 255 : br
                diff[o + 3] = 255

                // Heatmap: intensity from max channel delta, mapped to red channel
                let maxDelta = UInt8(min(255, max(db, max(dg, max(dr, da)))))
                heat[o + 0] = 0
                heat[o + 1] = 0
                heat[o + 2] = maxDelta // use R channel for heat
                heat[o + 3] = 255
            }
        }
        return (failures, diff, heat)
    }

    // MARK: - Config
    static func resolveTolerance(width: Int, height: Int, testName: String) -> ChannelTolerance {
        // Defaults
        var tol = ChannelTolerance(r: 2, g: 2, b: 2, a: 0, global: 2)
        do {
            let cwd = FileManager.default.currentDirectoryPath
            let cfgURL = URL(fileURLWithPath: cwd).appendingPathComponent("Resources/communication/visual_test_config.json")
            guard FileManager.default.fileExists(atPath: cfgURL.path) else { return tol }
            let data = try Data(contentsOf: cfgURL)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // default
                if let def = json["default"] as? [String: Any] {
                    tol = mergeTol(base: tol, src: def)
                }
                // byResolution: key like "64x64"
                let key = "\(width)x\(height)"
                if let byRes = json["byResolution"] as? [String: Any], let res = byRes[key] as? [String: Any] {
                    tol = mergeTol(base: tol, src: res)
                }
                // byTest: fully qualified test name
                if let byTest = json["byTest"] as? [String: Any], let tst = byTest[testName] as? [String: Any] {
                    tol = mergeTol(base: tol, src: tst)
                }
            }
        } catch {
            // ignore, keep defaults
        }
        // Env overrides (optional)
        let env = ProcessInfo.processInfo.environment
        if let s = env["VIS_TOL_R"], let v = Int(s) { tol.r = v }
        if let s = env["VIS_TOL_G"], let v = Int(s) { tol.g = v }
        if let s = env["VIS_TOL_B"], let v = Int(s) { tol.b = v }
        if let s = env["VIS_TOL_A"], let v = Int(s) { tol.a = v }
        if let s = env["VIS_TOL_GLOBAL"], let v = Int(s) { tol.global = v }
        return tol
    }

    private static func mergeTol(base: ChannelTolerance, src: [String: Any]) -> ChannelTolerance {
        var t = base
        if let v = src["r"] as? Int { t.r = v }
        if let v = src["g"] as? Int { t.g = v }
        if let v = src["b"] as? Int { t.b = v }
        if let v = src["a"] as? Int { t.a = v }
        if let v = src["global"] as? Int { t.global = v }
        return t
    }
}
