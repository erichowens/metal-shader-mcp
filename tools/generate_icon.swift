#!/usr/bin/env swift
import AppKit
import Foundation

func color(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func drawIcon(size: Int, to url: URL) throws {
    let width = size
    let height = size
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw NSError(domain: "icon.gen", code: 1) }

    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { throw NSError(domain: "icon.gen", code: 2) }
    NSGraphicsContext.current = ctx

    let rect = NSRect(x: 0, y: 0, width: width, height: height)

    // Background gradient (deep blue -> indigo) with a subtle vignette
    let grad = NSGradient(colors: [
        color(0x0B1020),
        color(0x1E3A8A),
        color(0x3B82F6)
    ])
    grad?.draw(in: rect, angle: 90)

    // Subtle shader-like diagonal lines
    let stripeColor = color(0xFFFFFF, alpha: 0.05)
    stripeColor.setStroke()
    let spacing = CGFloat(size) / 18.0
    let stripeWidth = max(1.0, CGFloat(size) * 0.003)
    for i in stride(from: -CGFloat(size), through: CGFloat(size) * 2, by: spacing) {
        let p = NSBezierPath()
        p.lineWidth = stripeWidth
        p.move(to: CGPoint(x: i, y: 0))
        p.line(to: CGPoint(x: i + CGFloat(size), y: CGFloat(size)))
        p.stroke()
    }

    // Stylized "M" path
    let m = NSBezierPath()
    m.lineCapStyle = .round
    m.lineJoinStyle = .round
    let lw = CGFloat(size) * 0.12

    m.move(to: CGPoint(x: 0.20 * CGFloat(size), y: 0.22 * CGFloat(size)))
    m.line(to: CGPoint(x: 0.20 * CGFloat(size), y: 0.78 * CGFloat(size)))
    m.line(to: CGPoint(x: 0.50 * CGFloat(size), y: 0.42 * CGFloat(size)))
    m.line(to: CGPoint(x: 0.80 * CGFloat(size), y: 0.78 * CGFloat(size)))
    m.line(to: CGPoint(x: 0.80 * CGFloat(size), y: 0.22 * CGFloat(size)))

    // Outer cyan glow stroke
    color(0x67E8F9, alpha: 0.55).setStroke()
    m.lineWidth = lw * 1.18
    m.stroke()

    // Inner white stroke
    color(0xFFFFFF, alpha: 0.92).setStroke()
    m.lineWidth = lw
    m.stroke()

    // Subtle top highlight
    let highlight = NSGradient(colorsAndLocations:
        (color(0xFFFFFF, alpha: 0.22), 0.0),
        (color(0xFFFFFF, alpha: 0.0), 1.0)
    )
    let topRect = NSRect(x: 0, y: height/2, width: width, height: height/2)
    highlight?.draw(in: topRect, angle: 270)

    NSGraphicsContext.current = nil
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon.gen", code: 3)
    }
    try data.write(to: url)
}

let outPath = CommandLine.arguments.dropFirst().first ?? "icon_1024.png"
let sizeArg = Int(CommandLine.arguments.dropFirst(2).first ?? "1024") ?? 1024
let url = URL(fileURLWithPath: outPath)
try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try drawIcon(size: sizeArg, to: url)
print("Wrote icon to: \(outPath)")

