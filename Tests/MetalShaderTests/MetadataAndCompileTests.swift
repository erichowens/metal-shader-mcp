import XCTest
@testable import MetalShaderCore
import Metal

final class MetadataAndCompileTests: XCTestCase {
    func testShaderMetadataParsing() {
        let code = """
        /**
         * Wavy Plasma
         * A smooth oscillating color field demonstrating uniforms.
         */
        #include <metal_stdlib>
        using namespace metal;
        fragment float4 fragmentShader() { return float4(0,0,0,1); }
        """
        let meta = ShaderMetadata.from(code: code, path: "/tmp/wavy.metal")
        XCTAssertEqual(meta.name, "Wavy Plasma")
        XCTAssertTrue(meta.description.contains("oscillating"))
        XCTAssertEqual(meta.path, "/tmp/wavy.metal")
    }

    func testPipelineCreationSmoke() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal unavailable; skipping pipeline smoke test")
        }
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        vertex float4 vertexShader(uint vertexID [[vertex_id]]) {
            float2 positions[4] = { float2(-1,-1), float2(1,-1), float2(-1,1), float2(1,1) };
            return float4(positions[vertexID], 0, 1);
        }
        fragment float4 fragmentShader() { return float4(0.1, 0.2, 0.3, 1.0); }
        """
        let lib = try device.makeLibrary(source: source, options: nil)
        let v = lib.makeFunction(name: "vertexShader")
        let f = lib.makeFunction(name: "fragmentShader")
        XCTAssertNotNil(v)
        XCTAssertNotNil(f)
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = v
        desc.fragmentFunction = f
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        _ = try device.makeRenderPipelineState(descriptor: desc)
    }
}
