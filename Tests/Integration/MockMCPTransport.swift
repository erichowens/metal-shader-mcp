import Foundation
import Combine
@testable import MetalShaderStudio

/// Mock implementation of MCPTransport for testing.
/// Allows precise control over transport behavior without subprocess overhead.
///
/// Features:
/// - Inject canned responses for specific methods
/// - Simulate various failure modes (timeout, errors, crashes)
/// - Track request history
/// - Control connection state manually
/// - Simulate health check failures
///
/// Example usage:
/// ```swift
/// let mock = MockMCPTransport()
/// mock.setResponse(for: "set_shader", result: ["status": "ok"])
/// mock.setResponse(for: "ping", result: [:])
///
/// let client = MCPClient(transport: mock)
/// try await client.initialize()
/// try client.setShader(code: "test", description: nil, noSnapshot: true)
///
/// XCTAssertEqual(mock.requestHistory.count, 2) // initialize + setShader
/// ```
class MockMCPTransport: MCPTransport {
    // MARK: - State
    
    let connectionState = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private var isInitialized = false
    
    // MARK: - Request Tracking
    
    struct RequestRecord {
        let method: String
        let params: [String: Any]?
        let timestamp: Date
    }
    
    private(set) var requestHistory: [RequestRecord] = []
    
    // MARK: - Response Configuration
    
    private var responses: [String: ResponseBehavior] = [:]
    
    enum ResponseBehavior {
        case success(result: Any?)
        case error(code: Int, message: String)
        case timeout
        case crash
    }
    
    // MARK: - Health Check Configuration
    
    var healthCheckBehavior: HealthCheckBehavior = .healthy
    
    enum HealthCheckBehavior {
        case healthy
        case unhealthy
        case intermittent(successRate: Double) // 0.0 to 1.0
    }
    
    // MARK: - Initialization Behavior
    
    var initializationBehavior: InitializationBehavior = .success
    
    enum InitializationBehavior {
        case success
        case failure(MCPError)
        case delay(seconds: TimeInterval)
    }
    
    // MARK: - Response Setup
    
    /// Configure a response for a specific method
    func setResponse(for method: String, result: Any?) {
        responses[method] = .success(result: result)
    }
    
    /// Configure an error response for a specific method
    func setError(for method: String, code: Int, message: String) {
        responses[method] = .error(code: code, message: message)
    }
    
    /// Configure a timeout for a specific method
    func setTimeout(for method: String) {
        responses[method] = .timeout
    }
    
    /// Configure a crash for a specific method
    func setCrash(for method: String) {
        responses[method] = .crash
    }
    
    /// Clear all configured responses
    func clearResponses() {
        responses.removeAll()
    }
    
    /// Reset all state
    func reset() {
        clearResponses()
        requestHistory.removeAll()
        connectionState.send(.disconnected)
        isInitialized = false
        healthCheckBehavior = .healthy
        initializationBehavior = .success
    }
    
    // MARK: - MCPTransport Protocol
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        connectionState.send(.connecting)
        
        switch initializationBehavior {
        case .success:
            connectionState.send(.connected)
            isInitialized = true
            
        case .failure(let error):
            connectionState.send(.disconnected)
            throw error
            
        case .delay(let seconds):
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            connectionState.send(.connected)
            isInitialized = true
        }
    }
    
    func shutdown() async {
        connectionState.send(.disconnected)
        isInitialized = false
    }
    
    func sendRequest(
        method: String,
        params: [String: Any]?,
        timeout: TimeInterval
    ) async throws -> Any? {
        guard isInitialized else {
            throw MCPError.notConnected
        }
        
        // Record the request
        let record = RequestRecord(
            method: method,
            params: params,
            timestamp: Date()
        )
        requestHistory.append(record)
        
        // Look up configured response
        guard let behavior = responses[method] else {
            // Default: return empty success
            return nil
        }
        
        // Execute behavior
        switch behavior {
        case .success(let result):
            return result
            
        case .error(let code, let message):
            throw MCPError.serverError(code: code, message: message)
            
        case .timeout:
            // Simulate timeout by waiting longer than timeout
            try await Task.sleep(nanoseconds: UInt64((timeout + 1.0) * 1_000_000_000))
            throw MCPError.requestTimeout(method: method)
            
        case .crash:
            // Simulate crash by disconnecting and throwing error
            connectionState.send(.disconnected)
            isInitialized = false
            throw MCPError.transportError("Simulated crash")
        }
    }
    
    func isHealthy() async -> Bool {
        guard isInitialized else { return false }
        
        switch healthCheckBehavior {
        case .healthy:
            return true
            
        case .unhealthy:
            connectionState.send(.unhealthy)
            return false
            
        case .intermittent(let successRate):
            let random = Double.random(in: 0...1)
            let healthy = random < successRate
            if !healthy {
                connectionState.send(.unhealthy)
            } else if connectionState.value == .unhealthy {
                connectionState.send(.connected)
            }
            return healthy
        }
    }
    
    // MARK: - Test Helpers
    
    /// Check if a specific method was called
    func wasCalled(_ method: String) -> Bool {
        requestHistory.contains { $0.method == method }
    }
    
    /// Get all calls to a specific method
    func getCalls(to method: String) -> [RequestRecord] {
        requestHistory.filter { $0.method == method }
    }
    
    /// Get the most recent call to a method
    func getLastCall(to method: String) -> RequestRecord? {
        requestHistory.last { $0.method == method }
    }
    
    /// Manually set connection state (for simulating state changes)
    func setConnectionState(_ state: ConnectionState) {
        connectionState.send(state)
    }
}