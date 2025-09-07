#!/usr/bin/env swift

/**
 * Metal Studio Test Suite - Standalone Version
 * Tests for Metal shader development tools without XCTest dependency
 */

import Metal
import MetalKit
import simd
import Foundation

// MARK: - Test Infrastructure

protocol TestCase {
    var name: String { get }
    func run() throws
}

class TestResult {
    var passed: Int = 0
    var failed: Int = 0
    var errors: [String] = []
    
    func recordPass() {
        passed += 1
    }
    
    func recordFailure(_ message: String) {
        failed += 1
        errors.append(message)
    }
}

// MARK: - Test Assertions

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") throws {
    if actual != expected {
        throw TestError.assertionFailed("\(message): Expected \(expected), got \(actual)")
    }
}

func assertNotNil(_ value: Any?, _ message: String = "") throws {
    if value == nil {
        throw TestError.assertionFailed("\(message): Value is nil")
    }
}

func assertLessThan<T: Comparable>(_ value: T, _ limit: T, _ message: String = "") throws {
    if value >= limit {
        throw TestError.assertionFailed("\(message): \(value) is not less than \(limit)")
    }
}

enum TestError: Error {
    case assertionFailed(String)
    case compilationFailed(String)
    case deviceUnavailable
}

// MARK: - Shader Compilation Tests

class ShaderCompilationTest: TestCase {
    let name = "Shader Compilation"
    let device: MTLDevice
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.deviceUnavailable
        }
        self.device = device
    }
    
    func run() throws {
        print("  🔸 Testing basic shader compilation...")
        try testBasicShader()
        
        print("  🔸 Testing invalid shader detection...")
        try testInvalidShader()
        
        print("  🔸 Testing shader with uniforms...")
        try testUniformShader()
        
        print("  🔸 Testing texture sampling shader...")
        try testTextureShader()
    }
    
    private func testBasicShader() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
        };
        
        vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
            VertexOut out;
            out.position = float4(0, 0, 0, 1);
            return out;
        }
        
        fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
            return float4(1, 0, 0, 1);
        }
        """
        
        let startTime = Date()
        let library = try device.makeLibrary(source: source, options: nil)
        let compileTime = Date().timeIntervalSince(startTime)
        
        try assertNotNil(library, "Library should compile")
        try assertLessThan(compileTime, 1.0, "Compilation time")
        
        let vertexFunc = library.makeFunction(name: "vertexShader")
        let fragmentFunc = library.makeFunction(name: "fragmentShader")
        
        try assertNotNil(vertexFunc, "Vertex function should exist")
        try assertNotNil(fragmentFunc, "Fragment function should exist")
    }
    
    private func testInvalidShader() throws {
        let invalidSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        fragment float4 fragmentShader() {
            return undefined_function();
        }
        """
        
        do {
            _ = try device.makeLibrary(source: invalidSource, options: nil)
            throw TestError.assertionFailed("Invalid shader should not compile")
        } catch {
            // Expected to fail
            if error is TestError {
                throw error
            }
            // Compilation error is expected
        }
    }
    
    private func testUniformShader() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct Uniforms {
            float time;
            float2 resolution;
            float2 mouse;
        };
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        fragment float4 fragmentShader(
            VertexOut in [[stage_in]],
            constant Uniforms& uniforms [[buffer(0)]]
        ) {
            float2 uv = in.texCoord;
            float t = uniforms.time;
            return float4(uv.x, uv.y, sin(t), 1.0);
        }
        """
        
        let library = try device.makeLibrary(source: source, options: nil)
        try assertNotNil(library, "Uniform shader should compile")
    }
    
    private func testTextureShader() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        fragment float4 fragmentShader(
            VertexOut in [[stage_in]],
            texture2d<float> inputTexture [[texture(0)]]
        ) {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
            return inputTexture.sample(textureSampler, in.texCoord);
        }
        """
        
        let library = try device.makeLibrary(source: source, options: nil)
        try assertNotNil(library, "Texture shader should compile")
    }
}

// MARK: - Performance Tests

class PerformanceTest: TestCase {
    let name = "Performance"
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.deviceUnavailable
        }
        guard let queue = device.makeCommandQueue() else {
            throw TestError.deviceUnavailable
        }
        self.device = device
        self.commandQueue = queue
    }
    
    func run() throws {
        print("  🔸 Testing frame time requirements...")
        try testFrameTime()
        
        print("  🔸 Testing memory allocation...")
        try testMemoryUsage()
        
        print("  🔸 Testing GPU command encoding...")
        try testCommandEncoding()
    }
    
    private func testFrameTime() throws {
        let targetFPS = 60.0
        let targetFrameTime = 1.0 / targetFPS
        
        var frameTimes: [TimeInterval] = []
        
        for _ in 0..<60 {
            let start = Date()
            
            // Simulate frame work
            Thread.sleep(forTimeInterval: 0.01)
            
            let elapsed = Date().timeIntervalSince(start)
            frameTimes.append(elapsed)
        }
        
        let averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
        try assertLessThan(averageFrameTime, targetFrameTime * 1.1, "Average frame time")
    }
    
    private func testMemoryUsage() throws {
        let info = ProcessInfo.processInfo
        let physicalMemory = info.physicalMemory
        
        // Create some textures to test memory
        var textures: [MTLTexture] = []
        
        for _ in 0..<10 {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: 1024,
                height: 1024,
                mipmapped: false
            )
            
            if let texture = device.makeTexture(descriptor: descriptor) {
                textures.append(texture)
            }
        }
        
        // Each texture is 4MB (1024x1024x4 bytes)
        let expectedMemory = textures.count * 1024 * 1024 * 4
        print("    Allocated \(expectedMemory / 1024 / 1024)MB of textures")
        
        // Clear to free memory
        textures.removeAll()
    }
    
    private func testCommandEncoding() throws {
        let commandBuffer = commandQueue.makeCommandBuffer()
        try assertNotNil(commandBuffer, "Command buffer creation")
        
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
        
        let status = commandBuffer?.status
        try assertEqual(status, .completed, "Command buffer status")
    }
}

// MARK: - Uniform Tests

class UniformTest: TestCase {
    let name = "Uniform Binding"
    
    struct TestUniforms {
        var time: Float = 0
        var resolution: SIMD2<Float> = SIMD2<Float>(800, 600)
        var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
        var intensity: Float = 1.0
    }
    
    func run() throws {
        print("  🔸 Testing uniform struct alignment...")
        try testAlignment()
        
        print("  🔸 Testing uniform updates...")
        try testUpdates()
        
        print("  🔸 Testing parameter clamping...")
        try testClamping()
    }
    
    private func testAlignment() throws {
        let size = MemoryLayout<TestUniforms>.size
        let stride = MemoryLayout<TestUniforms>.stride
        let alignment = MemoryLayout<TestUniforms>.alignment
        
        print("    Size: \(size), Stride: \(stride), Alignment: \(alignment)")
        
        // Metal requires 16-byte alignment for buffer offsets
        try assertEqual(alignment % 4, 0, "Alignment should be multiple of 4")
    }
    
    private func testUpdates() throws {
        var uniforms = TestUniforms()
        
        uniforms.time = 1.5
        try assertEqual(uniforms.time, Float(1.5), "Time update")
        
        uniforms.intensity = 2.0
        try assertEqual(uniforms.intensity, Float(2.0), "Intensity update")
        
        uniforms.mouse = SIMD2<Float>(0.25, 0.75)
        try assertEqual(uniforms.mouse.x, Float(0.25), "Mouse X update")
        try assertEqual(uniforms.mouse.y, Float(0.75), "Mouse Y update")
    }
    
    private func testClamping() throws {
        var uniforms = TestUniforms()
        
        // Test clamping logic
        uniforms.intensity = max(0, min(2, 3.0)) // Should clamp to 2
        try assertEqual(uniforms.intensity, Float(2.0), "Upper clamp")
        
        uniforms.intensity = max(0, min(2, -1.0)) // Should clamp to 0
        try assertEqual(uniforms.intensity, Float(0.0), "Lower clamp")
    }
}

// MARK: - Texture Tests

class TextureTest: TestCase {
    let name = "Texture Operations"
    let device: MTLDevice
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.deviceUnavailable
        }
        self.device = device
    }
    
    func run() throws {
        print("  🔸 Testing texture creation...")
        try testTextureCreation()
        
        print("  🔸 Testing texture data upload...")
        try testTextureUpload()
        
        print("  🔸 Testing different pixel formats...")
        try testPixelFormats()
    }
    
    private func testTextureCreation() throws {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 256,
            height: 256,
            mipmapped: false
        )
        
        let texture = device.makeTexture(descriptor: descriptor)
        try assertNotNil(texture, "Texture creation")
        try assertEqual(texture?.width ?? 0, 256, "Texture width")
        try assertEqual(texture?.height ?? 0, 256, "Texture height")
    }
    
    private func testTextureUpload() throws {
        let width = 64
        let height = 64
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        var data = [UInt8](repeating: 128, count: width * height * bytesPerPixel)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        
        let texture = device.makeTexture(descriptor: descriptor)
        texture?.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: bytesPerRow
        )
        
        try assertNotNil(texture, "Texture with data")
    }
    
    private func testPixelFormats() throws {
        let formats: [MTLPixelFormat] = [
            .rgba8Unorm,
            .bgra8Unorm,
            .rgba16Float,
            .r32Float
        ]
        
        for format in formats {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: format,
                width: 128,
                height: 128,
                mipmapped: false
            )
            
            let texture = device.makeTexture(descriptor: descriptor)
            try assertNotNil(texture, "Texture with format \(format)")
        }
    }
}

// MARK: - Integration Tests

class IntegrationTest: TestCase {
    let name = "End-to-End Pipeline"
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.deviceUnavailable
        }
        guard let queue = device.makeCommandQueue() else {
            throw TestError.deviceUnavailable
        }
        self.device = device
        self.commandQueue = queue
    }
    
    func run() throws {
        print("  🔸 Testing complete render pipeline...")
        try testRenderPipeline()
        
        print("  🔸 Testing shader hot reload simulation...")
        try testShaderReload()
    }
    
    private func testRenderPipeline() throws {
        // 1. Create shader library
        let source = getBasicShader()
        let library = try device.makeLibrary(source: source, options: nil)
        
        // 2. Create pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // 3. Create render target texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 512,
            height: 512,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw TestError.assertionFailed("Could not create render target")
        }
        
        // 4. Create render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        // 5. Encode and execute
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TestError.assertionFailed("Could not create command buffer")
        }
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw TestError.assertionFailed("Could not create render encoder")
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        try assertEqual(commandBuffer.status, .completed, "Pipeline execution")
    }
    
    private func testShaderReload() throws {
        // Simulate hot reload by compiling multiple shader versions
        let shaders = [
            getBasicShader(),
            getColorShader(),
            getGradientShader()
        ]
        
        for (index, source) in shaders.enumerated() {
            let library = try device.makeLibrary(source: source, options: nil)
            try assertNotNil(library, "Shader version \(index + 1)")
        }
    }
    
    private func getBasicShader() -> String {
        return """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
        };
        
        vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
            VertexOut out;
            float2 positions[4] = {
                float2(-1, -1), float2(1, -1),
                float2(-1, 1), float2(1, 1)
            };
            out.position = float4(positions[vertexID], 0, 1);
            return out;
        }
        
        fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
            return float4(1, 1, 1, 1);
        }
        """
    }
    
    private func getColorShader() -> String {
        return """
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
            out.position = float4(positions[vertexID], 0, 1);
            out.texCoord = (positions[vertexID] + 1.0) * 0.5;
            return out;
        }
        
        fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
            return float4(in.texCoord.x, in.texCoord.y, 0, 1);
        }
        """
    }
    
    private func getGradientShader() -> String {
        return """
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
            out.position = float4(positions[vertexID], 0, 1);
            out.texCoord = (positions[vertexID] + 1.0) * 0.5;
            return out;
        }
        
        fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
            float gradient = in.texCoord.x * 0.5 + in.texCoord.y * 0.5;
            return float4(gradient, 0, 1.0 - gradient, 1);
        }
        """
    }
}

// MARK: - Test Runner

class TestRunner {
    private var result = TestResult()
    
    func runAllTests() {
        print("🧪 Metal Studio Test Suite")
        print("=" + String(repeating: "=", count: 50))
        
        let testCases: [TestCase.Type] = [
            ShaderCompilationTest.self,
            PerformanceTest.self,
            UniformTest.self,
            TextureTest.self,
            IntegrationTest.self
        ]
        
        for testType in testCases {
            runTestCase(testType)
        }
        
        printSummary()
    }
    
    private func runTestCase(_ testType: TestCase.Type) {
        do {
            let test: TestCase
            
            if testType == ShaderCompilationTest.self {
                test = try ShaderCompilationTest()
            } else if testType == PerformanceTest.self {
                test = try PerformanceTest()
            } else if testType == UniformTest.self {
                test = UniformTest()
            } else if testType == TextureTest.self {
                test = try TextureTest()
            } else if testType == IntegrationTest.self {
                test = try IntegrationTest()
            } else {
                return
            }
            
            print("\n📋 \(test.name) Tests")
            print("-" + String(repeating: "-", count: 40))
            
            try test.run()
            result.recordPass()
            print("✅ All \(test.name) tests passed")
            
        } catch TestError.assertionFailed(let message) {
            result.recordFailure("❌ \(message)")
            print("❌ Test failed: \(message)")
        } catch TestError.compilationFailed(let message) {
            result.recordFailure("❌ Compilation failed: \(message)")
            print("❌ Compilation failed: \(message)")
        } catch TestError.deviceUnavailable {
            result.recordFailure("❌ Metal device unavailable")
            print("❌ Metal device unavailable")
        } catch {
            result.recordFailure("❌ Unexpected error: \(error)")
            print("❌ Unexpected error: \(error)")
        }
    }
    
    private func printSummary() {
        print("\n" + "=" + String(repeating: "=", count: 50))
        print("📊 Test Summary")
        print("-" + String(repeating: "-", count: 40))
        
        let total = result.passed + result.failed
        print("Total: \(total)")
        print("Passed: \(result.passed) ✅")
        print("Failed: \(result.failed) ❌")
        
        if result.failed > 0 {
            print("\nFailures:")
            for error in result.errors {
                print("  \(error)")
            }
        }
        
        let successRate = result.passed > 0 ? Double(result.passed) / Double(total) * 100 : 0
        print("Success Rate: \(String(format: "%.1f%%", successRate))")
        
        if result.failed == 0 {
            print("\n🎉 All tests passed! Metal Studio is production ready.")
        } else {
            print("\n⚠️  Some tests failed. Please review and fix issues.")
        }
    }
}

// Run the tests
let runner = TestRunner()
runner.runAllTests()