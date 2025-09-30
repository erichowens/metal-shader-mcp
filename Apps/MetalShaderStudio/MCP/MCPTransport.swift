import Foundation
import Combine

/// Protocol defining the low-level JSON-RPC transport layer for MCP communication.
/// This abstraction allows for different transport implementations (stdio process, websocket, HTTP, etc.)
/// and enables dependency injection for testing.
///
/// Example usage:
/// ```swift
/// let transport = MCPStdioTransport(serverCommand: "node server.js")
/// let client = MCPClient(transport: transport)
/// try await client.initialize()
/// ```
///
/// For testing:
/// ```swift
/// let mockTransport = MockMCPTransport()
/// mockTransport.setResponse(for: "ping", result: ["status": "ok"])
/// let client = MCPClient(transport: mockTransport)
/// ```
protocol MCPTransport: AnyObject {
    // MARK: - Connection State
    
    /// Observable connection state. Publishers can be used to react to connection changes.
    var connectionState: CurrentValueSubject<ConnectionState, Never> { get }
    
    /// Check if the transport is currently healthy and able to process requests.
    /// This should perform a lightweight check (e.g., ping) and update connection state if unhealthy.
    /// - Returns: true if transport is healthy, false otherwise
    func isHealthy() async -> Bool
    
    // MARK: - Lifecycle
    
    /// Initialize and start the transport (e.g., launch subprocess, open connection).
    /// This should be idempotent - calling multiple times should not cause issues.
    /// - Throws: MCPError if initialization fails
    func initialize() async throws
    
    /// Gracefully shut down the transport (e.g., terminate subprocess, close connection).
    /// Should clean up all resources and update connection state to .disconnected.
    /// This should be idempotent.
    func shutdown() async
    
    // MARK: - Communication
    
    /// Send a JSON-RPC request and wait for a response.
    /// - Parameters:
    ///   - method: The JSON-RPC method name (e.g., "ping", "set_shader")
    ///   - params: Optional parameters dictionary to send with the request
    ///   - timeout: Maximum time to wait for a response
    /// - Returns: The result field from the JSON-RPC response, or nil if no result
    /// - Throws: MCPError if request fails, times out, or receives an error response
    func sendRequest(
        method: String,
        params: [String: Any]?,
        timeout: TimeInterval
    ) async throws -> Any?
}

/// Structured errors for MCP transport operations
enum MCPError: Error, CustomStringConvertible {
    case notConnected
    case connectionFailed(String)
    case requestTimeout(method: String)
    case serverError(code: Int, message: String)
    case invalidResponse(String)
    case transportError(String)
    
    var description: String {
        switch self {
        case .notConnected:
            return "MCP transport not connected"
        case .connectionFailed(let details):
            return "MCP connection failed: \(details)"
        case .requestTimeout(let method):
            return "MCP request timeout: \(method)"
        case .serverError(let code, let message):
            return "MCP server error [\(code)]: \(message)"
        case .invalidResponse(let details):
            return "MCP invalid response: \(details)"
        case .transportError(let details):
            return "MCP transport error: \(details)"
        }
    }
}