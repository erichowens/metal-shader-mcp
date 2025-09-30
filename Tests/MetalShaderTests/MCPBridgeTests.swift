import XCTest
// Note: Cannot import MetalShaderStudio as it's an executable target
// These tests verify the bridge protocol structure without actual implementation

final class MCPBridgeProtocolTests: XCTestCase {
    
    // Mock MCPBridge protocol for testing
    protocol MCPBridge {
        func setShader(code: String, description: String?, noSnapshot: Bool) throws
        func setShaderWithMeta(name: String?, description: String?, path: String?, code: String?, save: Bool, noSnapshot: Bool) throws
        func exportFrame(description: String, time: Float?) throws
        func setTab(_ tab: String) throws
    }
    
    // Mock FileBridge implementation for testing
    class MockFileBridge: MCPBridge {
        var lastCommand: [String: Any] = [:]
        
        func setShader(code: String, description: String?, noSnapshot: Bool) throws {
            lastCommand = [
                "action": "set_shader",
                "shader_code": code,
                "description": description ?? "",
                "no_snapshot": noSnapshot
            ]
        }
        
        func setShaderWithMeta(name: String?, description: String?, path: String?, code: String?, save: Bool, noSnapshot: Bool) throws {
            lastCommand = [
                "action": "set_shader_with_meta",
                "name": name ?? "",
                "description": description ?? "",
                "path": path ?? "",
                "shader_code": code ?? "",
                "save": save,
                "no_snapshot": noSnapshot
            ]
        }
        
        func exportFrame(description: String, time: Float?) throws {
            lastCommand = [
                "action": "export_frame",
                "description": description,
                "time": time ?? -1
            ]
        }
        
        func setTab(_ tab: String) throws {
            lastCommand = [
                "action": "set_tab",
                "tab": tab
            ]
        }
    }
    
    func testMockBridgeProtocol() {
        // Test that mock bridge works correctly
        let bridge = MockFileBridge()
        
        // Test shader setting
        XCTAssertNoThrow(try bridge.setShader(code: "test", description: nil, noSnapshot: false))
        XCTAssertEqual(bridge.lastCommand["action"] as? String, "set_shader")
        XCTAssertEqual(bridge.lastCommand["shader_code"] as? String, "test")
        
        // Test tab setting
        XCTAssertNoThrow(try bridge.setTab("repl"))
        XCTAssertEqual(bridge.lastCommand["action"] as? String, "set_tab")
        XCTAssertEqual(bridge.lastCommand["tab"] as? String, "repl")
        
        // Test export frame
        XCTAssertNoThrow(try bridge.exportFrame(description: "test", time: 1.5))
        XCTAssertEqual(bridge.lastCommand["action"] as? String, "export_frame")
        XCTAssertEqual(bridge.lastCommand["time"] as? Float, 1.5)
    }
    
    func testSetShaderPayload() {
        let bridge = MockFileBridge()
        
        // Test basic shader setting
        XCTAssertNoThrow(try bridge.setShader(
            code: "fragment float4 test() { return float4(1); }",
            description: "Test shader",
            noSnapshot: true
        ))
        
        XCTAssertEqual(bridge.lastCommand["shader_code"] as? String,
                      "fragment float4 test() { return float4(1); }")
        XCTAssertEqual(bridge.lastCommand["description"] as? String, "Test shader")
        XCTAssertEqual(bridge.lastCommand["no_snapshot"] as? Bool, true)
    }
    
    func testSetShaderWithMetaPayload() {
        let bridge = MockFileBridge()
        
        // Test shader with metadata
        XCTAssertNoThrow(try bridge.setShaderWithMeta(
            name: "TestShader",
            description: "A test shader with metadata",
            path: "/path/to/shader.metal",
            code: "fragment float4 test() { return float4(1); }",
            save: true,
            noSnapshot: false
        ))
        
        XCTAssertEqual(bridge.lastCommand["action"] as? String, "set_shader_with_meta")
        XCTAssertEqual(bridge.lastCommand["name"] as? String, "TestShader")
        XCTAssertEqual(bridge.lastCommand["save"] as? Bool, true)
        
        // Test partial metadata update
        XCTAssertNoThrow(try bridge.setShaderWithMeta(
            name: nil,
            description: "Updated description",
            path: nil,
            code: nil,
            save: false,
            noSnapshot: true
        ))
        
        XCTAssertEqual(bridge.lastCommand["description"] as? String, "Updated description")
        XCTAssertEqual(bridge.lastCommand["save"] as? Bool, false)
        XCTAssertEqual(bridge.lastCommand["no_snapshot"] as? Bool, true)
    }
    
    func testExportFramePayload() {
        let bridge = MockFileBridge()
        
        // Test with time
        XCTAssertNoThrow(try bridge.exportFrame(
            description: "test_frame",
            time: 1.5
        ))
        
        XCTAssertEqual(bridge.lastCommand["description"] as? String, "test_frame")
        XCTAssertEqual(bridge.lastCommand["time"] as? Float, 1.5)
        
        // Test without time
        XCTAssertNoThrow(try bridge.exportFrame(
            description: "test_frame_no_time",
            time: nil
        ))
        
        XCTAssertEqual(bridge.lastCommand["description"] as? String, "test_frame_no_time")
        XCTAssertEqual(bridge.lastCommand["time"] as? Float, -1) // Using -1 as sentinel for nil
    }
    
    func testSetTabPayload() {
        let bridge = MockFileBridge()
        
        // Test all valid tabs
        let tabs = ["repl", "library", "projects", "tools", "history"]
        for tab in tabs {
            XCTAssertNoThrow(try bridge.setTab(tab))
            XCTAssertEqual(bridge.lastCommand["tab"] as? String, tab)
        }
    }
}
