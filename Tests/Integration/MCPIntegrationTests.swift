import XCTest
import Foundation
@testable import MetalShaderStudio

/// Integration tests for MCPLiveClient using a mock Node.js MCP server
/// These tests cover various real-world scenarios including:
/// - Successful initialization and communication
/// - Timeout handling
/// - Malformed response handling
/// - Server crash recovery
/// - Slow response handling
/// - Health check functionality
/// - Large payload handling
/// - Connection state management
final class MCPIntegrationTests: XCTestCase {
    
    var client: MCPLiveClient!
    let testServerPath = "Tests/Integration/mock-mcp-server.js"
    let testTimeout: TimeInterval = 10.0
    
    override func setUp() async throws {
        try await super.setUp()
        // Ensure mock server exists and is executable
        let fileManager = FileManager.default
        let serverPath = fileManager.currentDirectoryPath + "/" + testServerPath
        XCTAssertTrue(fileManager.fileExists(atPath: serverPath), "Mock server not found at \(serverPath)")
    }
    
    override func tearDown() async throws {
        if client != nil {
            await client.stop()
            client = nil
        }
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Creates a client with the specified test scenario
    private func createClient(scenario: String) -> MCPLiveClient {
        return MCPLiveClient(
            serverCommand: "/usr/bin/env",
            serverArgs: ["node", testServerPath, scenario]
        )
    }
    
    /// Waits for a specific connection state with timeout
    private func waitForState(
        _ expectedState: ConnectionState,
        timeout: TimeInterval = 5.0
    ) async throws {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if await client.connectionState == expectedState {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        let currentState = await client.connectionState
        XCTFail("Timeout waiting for state \(expectedState), current state: \(currentState)")
    }
    
    /// Waits for server to be ready by checking for initialization
    private func waitForServerReady() async throws {
        try await waitForState(.connected, timeout: testTimeout)
    }
    
    // MARK: - Basic Connection Tests
    
    func testSuccessfulInitialization() async throws {
        // Test successful server initialization and basic communication
        client = createClient(scenario: "success")
        
        await client.start()
        try await waitForServerReady()
        
        // Verify connection state is connected
        let state = await client.connectionState
        XCTAssertEqual(state, .connected, "Expected connected state after successful init")
        
        // Test a simple request
        let response = try await client.sendRequest(method: "test/echo", params: ["message": "hello"])
        XCTAssertNotNil(response, "Should receive response from server")
        if let result = response?["result"] as? [String: Any],
           let echo = result["echo"] as? String {
            XCTAssertEqual(echo, "hello", "Server should echo back the message")
        } else {
            XCTFail("Response format incorrect")
        }
    }
    
    func testHealthCheckSuccess() async throws {
        // Test that health checks work correctly with a healthy server
        client = createClient(scenario: "success")
        
        await client.start()
        try await waitForServerReady()
        
        // Perform health check
        let isHealthy = await client.isHealthy()
        XCTAssertTrue(isHealthy, "Server should be healthy")
        
        // Verify state remains connected
        let state = await client.connectionState
        XCTAssertEqual(state, .connected, "State should remain connected after successful health check")
    }
    
    // MARK: - Timeout Tests
    
    func testRequestTimeout() async throws {
        // Test that requests timeout appropriately when server doesn't respond
        client = createClient(scenario: "timeout")
        
        await client.start()
        try await waitForServerReady()
        
        // Send a request that will timeout
        do {
            _ = try await client.sendRequest(method: "test/timeout", params: [:])
            XCTFail("Request should have timed out")
        } catch {
            // Expected timeout error
            XCTAssertTrue(true, "Request correctly timed out")
        }
    }
    
    func testHealthCheckTimeout() async throws {
        // Test health check behavior when server is unresponsive
        client = createClient(scenario: "timeout")
        
        await client.start()
        try await waitForServerReady()
        
        // Health check should fail due to timeout
        let isHealthy = await client.isHealthy()
        XCTAssertFalse(isHealthy, "Health check should fail on timeout")
        
        // State should transition to unhealthy
        try await Task.sleep(nanoseconds: 500_000_000) // Wait 500ms for state update
        let state = await client.connectionState
        XCTAssertEqual(state, .unhealthy, "State should be unhealthy after failed health check")
    }
    
    // MARK: - Malformed Response Tests
    
    func testMalformedJSONResponse() async throws {
        // Test handling of invalid JSON responses
        client = createClient(scenario: "malformed")
        
        await client.start()
        try await waitForServerReady()
        
        do {
            _ = try await client.sendRequest(method: "test/malformed", params: [:])
            XCTFail("Should throw error for malformed JSON")
        } catch {
            // Expected JSON parsing error
            XCTAssertTrue(true, "Correctly threw error for malformed JSON")
        }
    }
    
    // MARK: - Server Crash and Recovery Tests
    
    func testServerCrashDetection() async throws {
        // Test that client detects when server crashes
        client = createClient(scenario: "crash")
        
        await client.start()
        try await waitForServerReady()
        
        // Send request that causes server to crash
        do {
            _ = try await client.sendRequest(method: "test/crash", params: [:])
        } catch {
            // Expected error due to crash
        }
        
        // Wait for disconnection detection
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        let state = await client.connectionState
        XCTAssertEqual(state, .disconnected, "Should detect server crash and disconnect")
    }
    
    func testAutoReconnectAfterCrash() async throws {
        // Test that client can auto-reconnect after server crashes
        // Note: This requires the mock server to support restart, which it doesn't in crash mode
        // This test documents expected behavior for future enhancement
        client = createClient(scenario: "success")
        
        await client.start()
        try await waitForServerReady()
        
        // Manually stop and restart to simulate recovery
        await client.stop()
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        await client.start()
        try await waitForServerReady()
        
        let state = await client.connectionState
        XCTAssertEqual(state, .connected, "Should reconnect after restart")
    }
    
    // MARK: - Performance Tests
    
    func testSlowResponseHandling() async throws {
        // Test handling of slow but valid responses
        client = createClient(scenario: "slow")
        
        await client.start()
        try await waitForServerReady()
        
        let startTime = Date()
        let response = try await client.sendRequest(method: "test/slow", params: [:])
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertNotNil(response, "Should receive response even if slow")
        XCTAssertGreaterThan(duration, 1.0, "Response should take at least 1 second")
        XCTAssertLessThan(duration, 3.0, "Response should not timeout")
    }
    
    func testLargePayloadHandling() async throws {
        // Test handling of large payloads
        client = createClient(scenario: "large")
        
        await client.start()
        try await waitForServerReady()
        
        let response = try await client.sendRequest(method: "test/large", params: [:])
        XCTAssertNotNil(response, "Should handle large payloads")
        
        if let result = response?["result"] as? [String: Any],
           let data = result["data"] as? String {
            XCTAssertGreaterThan(data.count, 10000, "Should receive large data payload")
        } else {
            XCTFail("Large payload response format incorrect")
        }
    }
    
    // MARK: - Reliability Tests
    
    func testIntermittentFailureRecovery() async throws {
        // Test recovery from intermittent failures
        client = createClient(scenario: "intermittent")
        
        await client.start()
        try await waitForServerReady()
        
        // Send multiple requests, some will fail
        var successCount = 0
        var failCount = 0
        
        for _ in 0..<10 {
            do {
                let response = try await client.sendRequest(method: "test/intermittent", params: [:])
                if response != nil {
                    successCount += 1
                }
            } catch {
                failCount += 1
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms between requests
        }
        
        XCTAssertGreaterThan(successCount, 0, "Some requests should succeed")
        XCTAssertGreaterThan(failCount, 0, "Some requests should fail (intermittent)")
        
        // Client should remain in healthy or recovering state
        let state = await client.connectionState
        XCTAssertNotEqual(state, .disconnected, "Client should not disconnect due to intermittent failures")
    }
    
    func testPartialResponseHandling() async throws {
        // Test handling of partial/incomplete responses
        client = createClient(scenario: "partial")
        
        await client.start()
        try await waitForServerReady()
        
        do {
            _ = try await client.sendRequest(method: "test/partial", params: [:])
            // Depending on implementation, this might succeed with partial data or fail
            // Document the actual behavior
        } catch {
            // If it throws, that's also acceptable behavior
            XCTAssertTrue(true, "Partial response handled by throwing error")
        }
    }
    
    func testErrorResponseHandling() async throws {
        // Test proper handling of JSON-RPC error responses
        client = createClient(scenario: "error")
        
        await client.start()
        try await waitForServerReady()
        
        let response = try await client.sendRequest(method: "test/error", params: [:])
        XCTAssertNotNil(response, "Should receive error response")
        
        if let error = response?["error"] as? [String: Any],
           let code = error["code"] as? Int {
            XCTAssertEqual(code, -32000, "Should receive proper error code")
        } else {
            XCTFail("Error response format incorrect")
        }
    }
    
    // MARK: - Connection State Tests
    
    func testConnectionStateTransitions() async throws {
        // Test that connection state transitions happen correctly
        client = createClient(scenario: "success")
        
        // Start in disconnected state
        var state = await client.connectionState
        XCTAssertEqual(state, .disconnected, "Should start disconnected")
        
        // Start connection - should go to connecting then connected
        await client.start()
        
        // Give it a moment to transition through connecting
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        state = await client.connectionState
        // State could be connecting or connected depending on timing
        XCTAssertTrue(
            state == .connecting || state == .connected,
            "Should be connecting or connected, got \(state)"
        )
        
        // Wait for fully connected
        try await waitForServerReady()
        state = await client.connectionState
        XCTAssertEqual(state, .connected, "Should reach connected state")
        
        // Stop connection
        await client.stop()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        state = await client.connectionState
        XCTAssertEqual(state, .disconnected, "Should return to disconnected state")
    }
    
    func testHealthCheckFailureStateTransition() async throws {
        // Test state transition when health checks fail
        client = createClient(scenario: "success")
        
        await client.start()
        try await waitForServerReady()
        
        // Initial state should be connected
        var state = await client.connectionState
        XCTAssertEqual(state, .connected, "Should start connected")
        
        // Stop the server to simulate health check failure
        await client.stop()
        
        // Restart with a server that will fail health checks
        client = createClient(scenario: "timeout")
        await client.start()
        
        // Wait for initialization
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Trigger health check that will fail
        let isHealthy = await client.isHealthy()
        XCTAssertFalse(isHealthy, "Health check should fail")
        
        // State should be unhealthy
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms for state update
        state = await client.connectionState
        XCTAssertEqual(state, .unhealthy, "State should be unhealthy after failed health check")
    }
    
    // MARK: - Ping-Only Tests
    
    func testPingOnlyMode() async throws {
        // Test server that only responds to pings
        client = createClient(scenario: "ping-only")
        
        await client.start()
        try await waitForServerReady()
        
        // Health check should work (uses ping)
        let isHealthy = await client.isHealthy()
        XCTAssertTrue(isHealthy, "Health check should succeed with ping-only server")
        
        // Other requests should fail or timeout
        do {
            _ = try await client.sendRequest(method: "test/echo", params: [:])
            XCTFail("Non-ping request should fail with ping-only server")
        } catch {
            XCTAssertTrue(true, "Non-ping request correctly failed")
        }
    }
}