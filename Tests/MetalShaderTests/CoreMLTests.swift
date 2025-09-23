import XCTest
@testable import MetalShaderCore
import Metal

final class CoreMLTests: XCTestCase {
    func testCoreMLPostProcessorDisabledWithoutConfig() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device not available")
        }
        let post = CoreMLPostProcessor(device: device)
        // If no valid config/model found, isEnabled should be false
        XCTAssertFalse(post.isEnabled, "Core ML should be disabled by default unless config/model is provided")
    }
}