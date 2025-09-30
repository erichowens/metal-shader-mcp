import Foundation
import Combine

/// High-level MCP client that implements the MCPBridge protocol.
/// Uses dependency injection to accept any MCPTransport implementation,
/// enabling testability and flexibility.
///
/// This class handles:
/// - High-level shader operations (setShader, exportFrame, etc.)
/// - Connection lifecycle management
/// - Health monitoring
/// - Error handling and retries
///
/// Example usage:
/// ```swift
/// // Production use with stdio transport
/// let transport = MCPStdioTransport(serverCommand: "node dist/index.js")
/// let client = MCPClient(transport: transport)
/// try await client.initialize()
/// try client.setShader(code: myShaderCode, description: "Test", noSnapshot: false)
/// ```
///
/// Example testing:
/// ```swift
/// // Testing with mock transport
/// let mockTransport = MockMCPTransport()
/// mockTransport.setResponse(for: "set_shader", result: [:])
/// let client = MCPClient(transport: mockTransport)
/// try client.setShader(code: "test", description: nil, noSnapshot: true)
/// ```
final class MCPClient: MCPBridge {
    // MARK: - Properties
    
    private let transport: MCPTransport
    private let defaultTimeout: TimeInterval
    private var isInitialized = false
    
    // MARK: - Initialization
    
    /// Create a new MCP client with the specified transport.
    /// - Parameters:
    ///   - transport: The transport layer to use for communication
    ///   - defaultTimeout: Default timeout for requests (default: 8.0 seconds)
    init(transport: MCPTransport, defaultTimeout: TimeInterval = 8.0) {
        self.transport = transport
        self.defaultTimeout = defaultTimeout
    }
    
    /// Convenience initializer that creates a stdio transport from a command string.
    /// - Parameters:
    ///   - serverCommand: The command to launch the MCP server (e.g., "node server.js")
    ///   - defaultTimeout: Default timeout for requests
    convenience init(serverCommand: String, defaultTimeout: TimeInterval = 8.0) {
        let transport = MCPStdioTransport(serverCommand: serverCommand)
        self.init(transport: transport, defaultTimeout: defaultTimeout)
    }
    
    // MARK: - Lifecycle
    
    /// Initialize the client and its transport. This must be called before using the client.
    /// This method is idempotent - calling it multiple times is safe.
    func initialize() async throws {
        guard !isInitialized else { return }
        
        try await transport.initialize()
        isInitialized = true
    }
    
    /// Shutdown the client and its transport gracefully.
    func shutdown() async {
        await transport.shutdown()
        isInitialized = false
    }
    
    /// Clean up on deinitialization
    deinit {
        // Note: Can't call async shutdown in deinit, but transport should handle cleanup
    }
    
    // MARK: - Connection State & Health
    
    /// Observable connection state from the transport
    var connectionState: CurrentValueSubject<ConnectionState, Never> {
        transport.connectionState
    }
    
    /// Check if the client and transport are healthy
    func isHealthy() async -> Bool {
        await transport.isHealthy()
    }
    
    // MARK: - MCPBridge Implementation
    
    func setShader(code: String, description: String?, noSnapshot: Bool) throws {
        try ensureInitialized()
        
        var params: [String: Any] = [
            "code": code,
            "noSnapshot": noSnapshot
        ]
        if let desc = description {
            params["description"] = desc
        }
        
        // Convert async to sync for MCPBridge protocol compatibility
        let semaphore = DispatchSemaphore(value: 0)
        var error: Error?
        
        Task {
            do {
                _ = try await transport.sendRequest(
                    method: "set_shader",
                    params: params,
                    timeout: defaultTimeout
                )
            } catch let e {
                error = e
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        if let error = error {
            throw error
        }
    }
    
    func setShaderWithMeta(
        name: String?,
        description: String?,
        path: String?,
        code: String?,
        save: Bool,
        noSnapshot: Bool
    ) throws {
        try ensureInitialized()
        
        var params: [String: Any] = [
            "save": save,
            "noSnapshot": noSnapshot
        ]
        if let n = name { params["name"] = n }
        if let d = description { params["description"] = d }
        if let p = path { params["path"] = p }
        if let c = code { params["code"] = c }
        
        let semaphore = DispatchSemaphore(value: 0)
        var error: Error?
        
        Task {
            do {
                _ = try await transport.sendRequest(
                    method: "set_shader_with_meta",
                    params: params,
                    timeout: defaultTimeout
                )
            } catch let e {
                error = e
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        if let error = error {
            throw error
        }
    }
    
    func exportFrame(description: String, time: Float?) throws {
        try ensureInitialized()
        
        var params: [String: Any] = ["description": description]
        if let t = time { params["time"] = t }
        
        let semaphore = DispatchSemaphore(value: 0)
        var error: Error?
        
        Task {
            do {
                _ = try await transport.sendRequest(
                    method: "export_frame",
                    params: params,
                    timeout: defaultTimeout
                )
            } catch let e {
                error = e
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        if let error = error {
            throw error
        }
    }
    
    func setTab(_ tab: String) throws {
        try ensureInitialized()
        
        let semaphore = DispatchSemaphore(value: 0)
        var error: Error?
        
        Task {
            do {
                _ = try await transport.sendRequest(
                    method: "set_tab",
                    params: ["tab": tab],
                    timeout: defaultTimeout
                )
            } catch let e {
                error = e
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        if let error = error {
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private func ensureInitialized() throws {
        guard isInitialized else {
            throw MCPError.notConnected
        }
    }
}