import XCTest
@testable import MetalShaderStudio

final class MCPBridgeProtocolTests: XCTestCase {
    
    func testMCPBridgeProtocol() {
        // Test that we can create and use the bridge protocol
        let fileBridge = FileBridgeMCP()
        let bridge: MCPBridge = fileBridge
        
        // Test that all required methods exist on the protocol
        XCTAssertNoThrow(try bridge.setShader(code: "test", description: nil, noSnapshot: false))
        XCTAssertNoThrow(try bridge.setTab("repl"))
        XCTAssertNoThrow(try bridge.exportFrame(description: "test", time: nil))
    }
    
    func testBridgeContainerCreation() {
        let fileBridge = FileBridgeMCP()
        let container = BridgeContainer(bridge: fileBridge)
        
        XCTAssertNotNil(container.bridge)
    }
    
    func testBridgeFactoryCreation() {
        let bridge = BridgeFactory.make()
        XCTAssertNotNil(bridge)
        
        // Should be able to call methods without throwing
        XCTAssertNoThrow(try bridge.setShader(code: "test", description: nil, noSnapshot: false))
    }
}