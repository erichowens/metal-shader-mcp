import XCTest
import Foundation
import Combine
@testable import MetalShaderStudio

/// Integration tests for MCP client architecture.
/// Tests the MCPClient wrapper with MockMCPTransport to validate:
/// - MCPBridge protocol implementation
/// - Connection lifecycle
/// - Health checking
/// - Error handling
/// - State transitions
///
/// These tests use dependency injection to test the client layer without subprocess overhead.
final class MCPClientIntegrationTests: XCTestCase {
    
    var mockTransport: MockMCPTransport!
    var client: MCPClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        mockTransport = MockMCPTransport()
        client = MCPClient(transport: mockTransport, defaultTimeout: 5.0)
        cancellables = []
    }
    
    override func tearDown() async throws {
        await client.shutdown()
        cancellables = nil
        mockTransport = nil
        client = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Connectivity Tests
    
    func testClientInitialization() async throws {
        // Test successful initialization
        try await client.initialize()
        
        // Verify connection state transitions
        XCTAssertEqual(mockTransport.connectionState.value, .connected)
    }
    
    func testInitializationIsIdempotent() async throws {
        // Initialize once
        try await client.initialize()
        let firstState = mockTransport.connectionState.value
        
        // Initialize again - should not error
        try await client.initialize()
        let secondState = mockTransport.connectionState.value
        
        // State should remain the same
        XCTAssertEqual(firstState, secondState)
    }
    
    func testInitializationFailure() async throws {
        // Configure transport to fail initialization
        mockTransport.initializationBehavior = .failure(.connectionFailed("Test failure"))
        
        do {
            try await client.initialize()
            XCTFail("Expected initialization to fail")
        } catch let error as MCPError {
            switch error {
            case .connectionFailed:
                XCTAssertTrue(true, "Correctly threw connection failed error")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
        
        XCTAssertEqual(mockTransport.connectionState.value, .disconnected)
    }
    
    // MARK: - MCPBridge Tests
    
    func testSetShader() async throws {
        // Set up mock response
        mockTransport.setResponse(for: "set_shader", result: ["status": "ok"])
        
        try await client.initialize()
        
        // Call setShader
        try client.setShader(code: "test shader code", description: "Test shader", noSnapshot: false)
        
        // Verify request was made
        XCTAssertTrue(mockTransport.wasCalled("set_shader"))
        
        // Verify parameters
        let call = mockTransport.getLastCall(to: "set_shader")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.params?["code"] as? String, "test shader code")
        XCTAssertEqual(call?.params?["description"] as? String, "Test shader")
        XCTAssertEqual(call?.params?["noSnapshot"] as? Bool, false)
    }
    
    func testSetShaderWithoutInitialization() throws {
        // Should fail if not initialized
        XCTAssertThrowsError(try client.setShader(code: "test", description: nil, noSnapshot: true)) { error in
            XCTAssertTrue(error is MCPError)
            if case MCPError.notConnected = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testSetShaderWithMeta() async throws {
        mockTransport.setResponse(for: "set_shader_with_meta", result: nil)
        
        try await client.initialize()
        
        try client.setShaderWithMeta(
            name: "TestShader",
            description: "A test",
            path: "/path/to/shader.metal",
            code: "shader code",
            save: true,
            noSnapshot: false
        )
        
        XCTAssertTrue(mockTransport.wasCalled("set_shader_with_meta"))
        
        let call = mockTransport.getLastCall(to: "set_shader_with_meta")
        XCTAssertEqual(call?.params?["name"] as? String, "TestShader")
        XCTAssertEqual(call?.params?["save"] as? Bool, true)
    }
    
    func testExportFrame() async throws {
        mockTransport.setResponse(for: "export_frame", result: ["path": "/exports/frame.png"])
        
        try await client.initialize()
        
        try client.exportFrame(description: "Test frame", time: 1.5)
        
        XCTAssertTrue(mockTransport.wasCalled("export_frame"))
        
        let call = mockTransport.getLastCall(to: "export_frame")
        XCTAssertEqual(call?.params?["description"] as? String, "Test frame")
        XCTAssertEqual(call?.params?["time"] as? Float, 1.5)
    }
    
    func testSetTab() async throws {
        mockTransport.setResponse(for: "set_tab", result: nil)
        
        try await client.initialize()
        
        try client.setTab("editor")
        
        XCTAssertTrue(mockTransport.wasCalled("set_tab"))
        
        let call = mockTransport.getLastCall(to: "set_tab")
        XCTAssertEqual(call?.params?["tab"] as? String, "editor")
    }
    
    // MARK: - Error Handling Tests
    
    func testServerError() async throws {
        // Configure transport to return an error
        mockTransport.setError(for: "set_shader", code: -32000, message: "Server error")
        
        try await client.initialize()
        
        XCTAssertThrowsError(try client.setShader(code: "test", description: nil, noSnapshot: true)) { error in
            if case let MCPError.serverError(code, message) = error {
                XCTAssertEqual(code, -32000)
                XCTAssertEqual(message, "Server error")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testTimeout() async throws {
        // Configure transport to timeout
        mockTransport.setTimeout(for: "set_shader")
        
        try await client.initialize()
        
        XCTAssertThrowsError(try client.setShader(code: "test", description: nil, noSnapshot: true)) { error in
            if case MCPError.requestTimeout = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testTransportCrash() async throws {
        // Configure transport to crash
        mockTransport.setCrash(for: "set_shader")
        
        try await client.initialize()
        
        XCTAssertThrowsError(try client.setShader(code: "test", description: nil, noSnapshot: true)) { error in
            if case MCPError.transportError = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
        
        // Connection should be disconnected after crash
        XCTAssertEqual(mockTransport.connectionState.value, .disconnected)
    }
    
    // MARK: - Health Check Tests
    
    func testHealthCheckHealthy() async throws {
        try await client.initialize()
        
        let isHealthy = await client.isHealthy()
        
        XCTAssertTrue(isHealthy)
        XCTAssertEqual(mockTransport.connectionState.value, .connected)
    }
    
    func testHealthCheckUnhealthy() async throws {
        mockTransport.healthCheckBehavior = .unhealthy
        
        try await client.initialize()
        
        let isHealthy = await client.isHealthy()
        
        XCTAssertFalse(isHealthy)
        XCTAssertEqual(mockTransport.connectionState.value, .unhealthy)
    }
    
    func testHealthCheckIntermittent() async throws {
        // 50% success rate
        mockTransport.healthCheckBehavior = .intermittent(successRate: 0.5)
        
        try await client.initialize()
        
        // Run multiple health checks
        var healthyCount = 0
        var unhealthyCount = 0
        
        for _ in 0..<20 {
            if await client.isHealthy() {
                healthyCount += 1
            } else {
                unhealthyCount += 1
            }
        }
        
        // Should have both healthy and unhealthy results
        XCTAssertGreaterThan(healthyCount, 0, "Should have some healthy checks")
        XCTAssertGreaterThan(unhealthyCount, 0, "Should have some unhealthy checks")
    }
    
    // MARK: - Connection State Tests
    
    func testConnectionStateTransitions() async throws {
        // Start disconnected
        XCTAssertEqual(mockTransport.connectionState.value, .disconnected)
        
        // Initialize - should go to connecting then connected
        try await client.initialize()
        XCTAssertEqual(mockTransport.connectionState.value, .connected)
        
        // Shutdown - should go to disconnected
        await client.shutdown()
        XCTAssertEqual(mockTransport.connectionState.value, .disconnected)
    }
    
    func testConnectionStateObservable() async throws {
        var stateChanges: [ConnectionState] = []
        
        // Subscribe to state changes
        mockTransport.connectionState
            .sink { state in
                stateChanges.append(state)
            }
            .store(in: &cancellables)
        
        // Initial state
        XCTAssertEqual(stateChanges.last, .disconnected)
        
        // Initialize
        try await client.initialize()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        XCTAssertEqual(stateChanges.last, .connected)
        
        // Should have seen: disconnected -> connecting -> connected
        XCTAssertTrue(stateChanges.contains(.connecting))
        XCTAssertTrue(stateChanges.contains(.connected))
    }
    
    // MARK: - Lifecycle Tests
    
    func testShutdown() async throws {
        try await client.initialize()
        XCTAssertEqual(mockTransport.connectionState.value, .connected)
        
        await client.shutdown()
        XCTAssertEqual(mockTransport.connectionState.value, .disconnected)
    }
    
    func testMultipleShutdowns() async throws {
        // Multiple shutdowns should be safe
        await client.shutdown()
        await client.shutdown()
        await client.shutdown()
        
        XCTAssertEqual(mockTransport.connectionState.value, .disconnected)
    }
    
    // MARK: - Request History Tests
    
    func testRequestHistoryTracking() async throws {
        mockTransport.setResponse(for: "set_shader", result: nil)
        mockTransport.setResponse(for: "export_frame", result: nil)
        
        try await client.initialize()
        
        // Make several requests
        try client.setShader(code: "shader1", description: nil, noSnapshot: true)
        try client.setShader(code: "shader2", description: nil, noSnapshot: true)
        try client.exportFrame(description: "frame", time: nil)
        
        // Verify history
        XCTAssertEqual(mockTransport.requestHistory.count, 3)
        XCTAssertEqual(mockTransport.getCalls(to: "set_shader").count, 2)
        XCTAssertEqual(mockTransport.getCalls(to: "export_frame").count, 1)
    }
}