import XCTest
import Metal

final class MetalShaderStudioTests: XCTestCase {
    func testMetalDeviceAvailable() {
        let device = MTLCreateSystemDefaultDevice()
        XCTAssertNotNil(device, "Metal device should be available on test machine")
    }
}
