import Foundation
import AppKit
import Metal

final class ThumbnailRenderer {
    static let shared = ThumbnailRenderer()
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?

    private init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
    }

    func renderThumbnail(from source: String, width: Int = 256, height: Int = 256) -> NSImage? {
        guard let device, let commandQueue else { return createPlaceholderThumbnail(width: width, height: height, message: "No GPU") }
        do {
            // Check if the shader source already has a vertex shader
            let hasVertexShader = source.contains("vertex") && source.contains("vertexShader")
            let fullSource = hasVertexShader ? source : vertexSource + "\n" + source
            let library = try device.makeLibrary(source: fullSource, options: nil)
            
            // Try different fragment function names
            var fragmentFunction: MTLFunction?
            let possibleNames = ["fragmentShader", "fragmentShaderSimple", "fragmentShaderFast"]
            
            for name in possibleNames {
                if let function = library.makeFunction(name: name) {
                    fragmentFunction = function
                    break
                }
            }
            
            guard let v = library.makeFunction(name: "vertexShader"),
                  let f = fragmentFunction else { 
                return createPlaceholderThumbnail(width: width, height: height, message: "Complex Shader")
            }
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = v
            desc.fragmentFunction = f
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            let pipeline = try device.makeRenderPipelineState(descriptor: desc)

            let tdesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            tdesc.usage = [.renderTarget, .shaderRead]
            guard let tex = device.makeTexture(descriptor: tdesc) else { return nil }

            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture = tex
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].storeAction = .store
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

            guard let cb = commandQueue.makeCommandBuffer(),
                  let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return nil }
            enc.setRenderPipelineState(pipeline)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            enc.endEncoding()
            cb.commit(); cb.waitUntilCompleted()

            // Readback
            let bpr = width * 4
            let size = bpr * height
            let bytes = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 1)
            defer { bytes.deallocate() }
            tex.getBytes(bytes, bytesPerRow: bpr, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

            // Create NSImage from BGRA8
            let cs = CGColorSpaceCreateDeviceRGB()
            let bmp = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            let dp = CGDataProvider(dataInfo: nil, data: bytes, size: size, releaseData: {_,_,_ in})!
            guard let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bpr, space: cs, bitmapInfo: bmp, provider: dp, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
            return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
        } catch {
            print("ThumbnailRenderer error: \(error)")
            return createPlaceholderThumbnail(width: width, height: height, message: "Compile Error")
        }
    }
    
    private func createPlaceholderThumbnail(width: Int, height: Int, message: String) -> NSImage? {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        
        // Gradient background based on message type
        let gradient: NSGradient
        if message.contains("Complex") {
            gradient = NSGradient(colors: [NSColor.systemBlue.withAlphaComponent(0.3), NSColor.systemPurple.withAlphaComponent(0.3)])!
        } else if message.contains("Error") {
            gradient = NSGradient(colors: [NSColor.systemRed.withAlphaComponent(0.3), NSColor.systemOrange.withAlphaComponent(0.3)])!
        } else {
            gradient = NSGradient(colors: [NSColor.systemGray.withAlphaComponent(0.3), NSColor.systemGray])!
        }
        
        gradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 45)
        
        // Icon and text
        let fontSize = CGFloat(min(width, height)) / 8
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        
        let icon = message.contains("Complex") ? "⚙️" : (message.contains("Error") ? "⚠️" : "🖼️")
        let iconSize = icon.size(withAttributes: attributes)
        let iconRect = NSRect(
            x: (width - Int(iconSize.width)) / 2,
            y: (height - Int(iconSize.height)) / 2 + 10,
            width: Int(iconSize.width),
            height: Int(iconSize.height)
        )
        icon.draw(in: iconRect, withAttributes: attributes)
        
        // Message text
        let textFont = NSFont.systemFont(ofSize: fontSize * 0.5)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let textSize = message.size(withAttributes: textAttributes)
        let textRect = NSRect(
            x: (width - Int(textSize.width)) / 2,
            y: (height - Int(textSize.height)) / 2 - 20,
            width: Int(textSize.width),
            height: Int(textSize.height)
        )
        message.draw(in: textRect, withAttributes: textAttributes)
        
        image.unlockFocus()
        return image
    }

    private let vertexSource = """
    #include <metal_stdlib>
    using namespace metal;
    
    // Default vertex shader for simple fragment-only shaders
    // This is only used when the shader doesn't define its own vertex shader
    vertex float4 vertexShader(uint vid [[vertex_id]]) {
        float2 p[4] = { float2(-1,-1), float2(1,-1), float2(-1,1), float2(1,1) };
        return float4(p[vid], 0, 1);
    }
    """
}