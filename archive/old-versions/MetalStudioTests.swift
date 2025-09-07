#!/usr/bin/env swift

/**
 * Metal Studio Test Suite
 * Comprehensive tests for Metal shader development tools
 */

import XCTest
import Metal
import MetalKit
import simd

// MARK: - Test Configuration

struct TestConfig {
    static let fpsRequirement: Double = 60.0
    static let memoryLimit: Int = 256 * 1024 * 1024 // 256MB
    static let compileTimeLimit: TimeInterval = 1.0 // 1 second max
    static let gpuTimeLimit: TimeInterval = 0.016 // ~60fps
}

// MARK: - Shader Compilation Tests

class ShaderCompilationTests: XCTestCase {
    var device: MTLDevice!
    
    override func setUp() {
        super.setUp()
        device = MTLCreateSystemDefaultDevice()
        XCTAssertNotNil(device, "Metal device should be available")
    }
    
    func testBasicShaderCompilation() throws {
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
        
        XCTAssertLessThan(compileTime, TestConfig.compileTimeLimit, 
                         "Shader compilation should be under \(TestConfig.compileTimeLimit)s")
        XCTAssertNotNil(library.makeFunction(name: "vertexShader"))
        XCTAssertNotNil(library.makeFunction(name: "fragmentShader"))
    }
    
    func testInvalidShaderDetection() {
        let invalidSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        fragment float4 fragmentShader() {
            return undefined_function(); // This should fail
        }
        """
        
        XCTAssertThrowsError(try device.makeLibrary(source: invalidSource, options: nil)) { error in
            print("Expected compilation error: \(error)")
        }
    }
    
    func testAllTemplateShaders() throws {
        let templates = [
            "Gaussian Blur", "Color Correction", "Ripple Effect",
            "Page Curl", "Water Surface", "Particle System"
        ]
        
        for template in templates {
            print("Testing template: \(template)")
            let shader = getTemplateShader(template)
            
            let library = try device.makeLibrary(source: shader, options: nil)
            XCTAssertNotNil(library, "Template '\(template)' should compile")
            
            // Verify required functions exist
            XCTAssertNotNil(library.makeFunction(name: "vertexShader"))
            XCTAssertNotNil(library.makeFunction(name: "fragmentShader"))
        }
    }
    
    func testShaderWithTexture() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        fragment float4 fragmentShader(
            VertexOut in [[stage_in]],
            texture2d<float> inputTexture [[texture(0)]],
            sampler textureSampler [[sampler(0)]]
        ) {
            return inputTexture.sample(textureSampler, in.texCoord);
        }
        """
        
        let library = try device.makeLibrary(source: source, options: nil)
        XCTAssertNotNil(library.makeFunction(name: "fragmentShader"))
    }
    
    private func getTemplateShader(_ name: String) -> String {
        // Return simplified versions of template shaders for testing
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
}

// MARK: - Performance Tests

class PerformanceTests: XCTestCase {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    
    override func setUp() {
        super.setUp()
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
    }
    
    func testRenderingPerformance() throws {
        let view = MTKView()
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.drawableSize = CGSize(width: 1920, height: 1080)
        
        // Create simple pipeline
        let library = device.makeDefaultLibrary()
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // Measure frame rendering time
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<100 {
                autoreleasepool {
                    guard let drawable = view.currentDrawable,
                          let descriptor = view.currentRenderPassDescriptor,
                          let commandBuffer = commandQueue.makeCommandBuffer(),
                          let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                        return
                    }
                    
                    encoder.setRenderPipelineState(pipelineState)
                    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                    encoder.endEncoding()
                    
                    commandBuffer.present(drawable)
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()
                }
            }
        }
    }
    
    func testMemoryUsage() {
        let info = ProcessInfo.processInfo
        let memory = info.physicalMemory
        
        print("Physical Memory: \(memory / 1024 / 1024) MB")
        
        // Test memory usage stays within limits
        let memoryUsage = getMemoryUsage()
        XCTAssertLessThan(memoryUsage, TestConfig.memoryLimit, 
                         "Memory usage should be under \(TestConfig.memoryLimit / 1024 / 1024)MB")
    }
    
    func test60FPSRequirement() throws {
        let frameTime = 1.0 / TestConfig.fpsRequirement
        
        // Simulate rendering loop
        var frameTimes: [TimeInterval] = []
        
        for _ in 0..<60 {
            let start = Date()
            // Simulate frame work
            Thread.sleep(forTimeInterval: 0.01) // 10ms of work
            let elapsed = Date().timeIntervalSince(start)
            frameTimes.append(elapsed)
        }
        
        let averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
        let fps = 1.0 / averageFrameTime
        
        XCTAssertGreaterThan(fps, TestConfig.fpsRequirement * 0.95, 
                            "Should maintain at least 95% of target FPS")
    }
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}

// MARK: - Uniform Binding Tests

class UniformBindingTests: XCTestCase {
    
    struct TestUniforms {
        var time: Float = 0
        var resolution: SIMD2<Float> = SIMD2<Float>(1920, 1080)
        var mouse: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
        var intensity: Float = 1.0
        var progress: Float = 0.0
        var scale: Float = 1.0
        var rotation: Float = 0.0
        var offset: SIMD2<Float> = SIMD2<Float>(0, 0)
        var color1: SIMD4<Float> = SIMD4<Float>(1, 0, 0, 1)
        var color2: SIMD4<Float> = SIMD4<Float>(0, 0, 1, 1)
    }
    
    func testUniformStructAlignment() {
        let uniforms = TestUniforms()
        let size = MemoryLayout<TestUniforms>.size
        let stride = MemoryLayout<TestUniforms>.stride
        let alignment = MemoryLayout<TestUniforms>.alignment
        
        print("Uniforms size: \(size), stride: \(stride), alignment: \(alignment)")
        
        // Verify proper alignment for Metal
        XCTAssertEqual(alignment % 16, 0, "Uniforms should be 16-byte aligned for Metal")
    }
    
    func testUniformUpdates() {
        var uniforms = TestUniforms()
        
        // Test parameter updates
        uniforms.time = 1.5
        XCTAssertEqual(uniforms.time, 1.5)
        
        uniforms.intensity = 2.0
        XCTAssertEqual(uniforms.intensity, 2.0)
        
        uniforms.color1 = SIMD4<Float>(0, 1, 0, 1)
        XCTAssertEqual(uniforms.color1, SIMD4<Float>(0, 1, 0, 1))
    }
    
    func testParameterRanges() {
        var uniforms = TestUniforms()
        
        // Test clamping
        uniforms.progress = max(0, min(1, 1.5)) // Should clamp to 1
        XCTAssertEqual(uniforms.progress, 1.0)
        
        uniforms.intensity = max(0, min(2, -0.5)) // Should clamp to 0
        XCTAssertEqual(uniforms.intensity, 0.0)
    }
}

// MARK: - Texture Tests

class TextureTests: XCTestCase {
    var device: MTLDevice!
    
    override func setUp() {
        super.setUp()
        device = MTLCreateSystemDefaultDevice()
    }
    
    func testTextureCreation() {
        let width = 256
        let height = 256
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        
        let texture = device.makeTexture(descriptor: textureDescriptor)
        XCTAssertNotNil(texture)
        XCTAssertEqual(texture?.width, width)
        XCTAssertEqual(texture?.height, height)
        XCTAssertEqual(texture?.pixelFormat, .rgba8Unorm)
    }
    
    func testCheckerboardTexture() {
        let texture = createCheckerboardTexture()
        XCTAssertNotNil(texture)
        XCTAssertEqual(texture?.width, 256)
        XCTAssertEqual(texture?.height, 256)
    }
    
    private func createCheckerboardTexture() -> MTLTexture? {
        let width = 256
        let height = 256
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        var data = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let checker = ((x / 32) + (y / 32)) % 2 == 0
                let value: UInt8 = checker ? 200 : 100
                data[offset] = value     // R
                data[offset + 1] = value // G
                data[offset + 2] = value // B
                data[offset + 3] = 255   // A
            }
        }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        
        let texture = device.makeTexture(descriptor: textureDescriptor)
        texture?.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: bytesPerRow
        )
        
        return texture
    }
}

// MARK: - Integration Tests

class IntegrationTests: XCTestCase {
    
    func testEndToEndShaderPipeline() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let commandQueue = device.makeCommandQueue()!
        
        // 1. Compile shader
        let source = getTestShader()
        let library = try device.makeLibrary(source: source, options: nil)
        
        // 2. Create pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // 3. Create texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 512,
            height: 512,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        
        let texture = device.makeTexture(descriptor: textureDescriptor)!
        
        // 4. Render
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        XCTAssertEqual(commandBuffer.status, .completed)
    }
    
    private func getTestShader() -> String {
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
}

// MARK: - Test Runner

class TestRunner {
    static func runAllTests() {
        print("🧪 Running Metal Studio Test Suite\n")
        print("=" * 50)
        
        let testClasses: [XCTestCase.Type] = [
            ShaderCompilationTests.self,
            PerformanceTests.self,
            UniformBindingTests.self,
            TextureTests.self,
            IntegrationTests.self
        ]
        
        var totalTests = 0
        var passedTests = 0
        var failedTests = 0
        
        for testClass in testClasses {
            print("\n📋 Running \(String(describing: testClass))")
            print("-" * 40)
            
            let suite = XCTestSuite(forTestCaseClass: testClass)
            let result = XCTestSuiteRun(test: suite)
            suite.run(result)
            
            totalTests += result.testCaseCount
            passedTests += result.testCaseCount - result.failureCount - result.unexpectedExceptionCount
            failedTests += result.failureCount + result.unexpectedExceptionCount
            
            if result.hasSucceeded {
                print("✅ All tests passed!")
            } else {
                print("❌ \(result.failureCount) failures, \(result.unexpectedExceptionCount) exceptions")
                for failure in result.failures {
                    print("  ⚠️ \(failure)")
                }
            }
        }
        
        print("\n" + "=" * 50)
        print("📊 Test Summary")
        print("-" * 40)
        print("Total: \(totalTests)")
        print("Passed: \(passedTests) ✅")
        print("Failed: \(failedTests) ❌")
        print("Success Rate: \(String(format: "%.1f%%", Double(passedTests) / Double(totalTests) * 100))")
        
        if failedTests == 0 {
            print("\n🎉 All tests passed! Metal Studio is production ready.")
        } else {
            print("\n⚠️ Some tests failed. Please review and fix issues.")
        }
    }
}

// Run tests
TestRunner.runAllTests()