import XCTest

final class MetalShaderStudioUITests: XCTestCase {
    func testLaunchShowsMainWindow() {
        let app = XCUIApplication()
        app.launch()
        // Expect at least one window to exist
        XCTAssertTrue(app.windows.element(boundBy: 0).exists, "Main window should exist after launch")
    }
}
