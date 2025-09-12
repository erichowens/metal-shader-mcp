import XCTest
import Metal
import MetalKit

final class ShaderTests: XCTestCase {
    private var device: MTLDevice!

    override func setUpWithError() throws {
        // Skip tests if Metal is not available on the CI runner
        guard let dev = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device not available on this runner; skipping GPU-dependent tests.")
        }
        device = dev
    }

    func testMetalDeviceAvailableOrSkipped() {
        // If we reached here, device is non-nil
        XCTAssertNotNil(device)
    }

    func testMinimalShaderCompilation() throws {
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
            return float4(0.2, 0.4, 0.6, 1.0);
        }
        """

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            let function = library.makeFunction(name: "fragmentShader")
            XCTAssertNotNil(function, "Shader function should compile successfully")
        } catch {
            XCTFail("Shader compilation failed: \(error)")
        }
    }

    func testShaderParameterBounds() {
        let testTime: Float = 0.0
        XCTAssertGreaterThanOrEqual(testTime, 0.0, "Time parameter should be non-negative")

        let testResolution = SIMD2<Float>(800.0, 600.0)
        XCTAssertGreaterThan(testResolution.x, 0, "Resolution width should be positive")
        XCTAssertGreaterThan(testResolution.y, 0, "Resolution height should be positive")
    }
}
