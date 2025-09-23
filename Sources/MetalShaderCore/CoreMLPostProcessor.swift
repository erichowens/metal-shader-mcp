import Foundation
import CoreML
import Metal
import MetalKit
import CoreVideo

public final class CoreMLPostProcessor {
    public struct Config: Codable {
        public let modelPath: String
        public let inputName: String
        public let outputName: String
        public let width: Int
        public let height: Int
    }

    private let device: MTLDevice
    private var model: MLModel?
    private var config: Config?
    private var textureCache: CVMetalTextureCache?
    private let configPath = "Resources/communication/coreml_config.json"
    private var lastConfigMtime: Date?

    public init(device: MTLDevice) {
        self.device = device
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        reloadConfigIfNeeded(force: true)
    }

    public func reloadConfigIfNeeded(force: Bool = false) {
        let url = URL(fileURLWithPath: configPath)
        guard FileManager.default.fileExists(atPath: configPath) else { return }
        let attrs = try? FileManager.default.attributesOfItem(atPath: configPath)
        let mtime = attrs?[.modificationDate] as? Date
        guard force || mtime != lastConfigMtime else { return }
        do {
            let data = try Data(contentsOf: url)
            let cfg = try JSONDecoder().decode(Config.self, from: data)
            let modelURL = URL(fileURLWithPath: cfg.modelPath)
            let compiledURL: URL
            if modelURL.pathExtension == "mlmodelc" {
                compiledURL = modelURL
            } else if modelURL.pathExtension == "mlmodel" {
                compiledURL = try MLModel.compileModel(at: modelURL)
            } else {
                // Attempt to load as compiled directory
                compiledURL = modelURL
            }
            let mlModel = try MLModel(contentsOf: compiledURL)
            self.model = mlModel
            self.config = cfg
            self.lastConfigMtime = mtime
            fputs("[CoreML] Loaded model from \(cfg.modelPath)\n", stderr)
        } catch {
            fputs("[CoreML] Failed to load config/model: \(error)\n", stderr)
        }
    }

    public var isEnabled: Bool { model != nil && config != nil }

    // Process an input texture through the ML model and return an output texture. Returns nil if unavailable.
    public func process(texture inTex: MTLTexture) -> MTLTexture? {
        reloadConfigIfNeeded()
        guard let model, let cfg = config, let cache = textureCache else { return nil }

        // Create input CVPixelBuffer of expected size
        guard let inputPB = Self.makePixelBuffer(width: cfg.width, height: cfg.height) else { return nil }

        // Blit/scale the input texture into the pixel buffer via temporary texture
        guard let inputCVTex = Self.makeCVMetalTexture(from: inputPB, pixelFormat: .bgra8Unorm, width: cfg.width, height: cfg.height, cache: cache),
              let inputTex = CVMetalTextureGetTexture(inputCVTex) else { return nil }

        // Create command queue and blit from inTex -> inputTex (scale if sizes differ)
        guard let commandQueue = device.makeCommandQueue(), let cmdBuf = commandQueue.makeCommandBuffer(), let blit = cmdBuf.makeBlitCommandEncoder() else { return nil }
        let dstSize = MTLSize(width: min(cfg.width, inTex.width), height: min(cfg.height, inTex.height), depth: 1)
        blit.copy(from: inTex, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: inTex.width, height: inTex.height, depth: 1), to: inputTex, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blit.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        // Run Core ML prediction
        do {
            let input = MLDictionaryFeatureProvider(dictionary: [cfg.inputName: MLFeatureValue(pixelBuffer: inputPB)])
            let out = try model.prediction(from: input)
            guard let outPB = out.featureValue(for: cfg.outputName)?.imageBufferValue ?? out.featureValue(for: cfg.outputName)?.pixelBufferValue else {
                fputs("[CoreML] Output feature not found: \(cfg.outputName)\n", stderr)
                return nil
            }
            // Wrap output pixel buffer as Metal texture
            guard let outCVTex = Self.makeCVMetalTexture(from: outPB, pixelFormat: .bgra8Unorm, width: CVPixelBufferGetWidth(outPB), height: CVPixelBufferGetHeight(outPB), cache: cache),
                  let outTex = CVMetalTextureGetTexture(outCVTex) else { return nil }

            // If output texture is already fine, return a dedicated copy in Private storage for downstream usage
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: outTex.pixelFormat, width: outTex.width, height: outTex.height, mipmapped: false)
            desc.usage = [.shaderRead, .shaderWrite, .renderTarget, .blit]
            desc.storageMode = .private
            guard let finalTex = device.makeTexture(descriptor: desc),
                  let cq = device.makeCommandQueue(), let bcb = cq.makeCommandBuffer(), let bl = bcb.makeBlitCommandEncoder() else { return nil }
            bl.copy(from: outTex, to: finalTex)
            bl.endEncoding()
            bcb.commit()
            bcb.waitUntilCompleted()
            return finalTex
        } catch {
            fputs("[CoreML] Prediction error: \(error)\n", stderr)
            return nil
        }
    }

    private static func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb)
        return pb
    }

    private static func makeCVMetalTexture(from pb: CVPixelBuffer, pixelFormat: MTLPixelFormat, width: Int, height: Int, cache: CVMetalTextureCache) -> CVMetalTexture? {
        var cvTex: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, pb, nil, pixelFormat, width, height, 0, &cvTex)
        return cvTex
    }
}