import Foundation
import Combine

/// Stdio-based JSON-RPC transport for MCP servers.
/// Launches a subprocess and communicates via stdin/stdout using newline-delimited JSON-RPC messages.
///
/// Features:
/// - Subprocess lifecycle management
/// - Health monitoring with automatic restart
/// - Connection state tracking
/// - Request/response correlation
/// - Buffer management and size limits
///
/// Example:
/// ```swift
/// let transport = MCPStdioTransport(serverCommand: "node dist/index.js")
/// try await transport.initialize()
/// let result = try await transport.sendRequest(method: "ping", params: nil, timeout: 5.0)
/// ```
final class MCPStdioTransport: MCPTransport {
    // MARK: - Properties
    
    private let serverCommand: String
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    
    private let rpcQueue = DispatchQueue(label: "mcp.stdio.rpc.queue")
    private var nextId: Int = 1
    private var pending: [Int: (signal: DispatchSemaphore, storage: ResponseBox)] = [:]
    private var readBuffer = Data()
    
    // Config
    private let maxBufferSize = 10_000_000  // 10MB limit for readBuffer
    private let maxMessageSize = 5_000_000  // 5MB limit per message
    
    // Health check & connection state
    let connectionState = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private var healthCheckTimer: Timer?
    private var consecutiveFailures: Int = 0
    private let maxFailures = 3
    private let healthCheckInterval: TimeInterval = 30.0
    private let healthCheckTimeout: TimeInterval = 2.0
    
    // MARK: - Initialization
    
    init(serverCommand: String) {
        self.serverCommand = serverCommand
    }
    
    deinit {
        stopHealthCheck()
        terminateChild()
    }
    
    // MARK: - MCPTransport Protocol
    
    func initialize() async throws {
        // Idempotent - if already launched, do nothing
        guard process == nil else { return }
        
        connectionState.send(.connecting)
        
        // Parse command with proper argument handling
        let parts = parseShellCommand(serverCommand)
        guard let exe = parts.first else {
            throw MCPError.connectionFailed("Server command is empty or invalid")
        }
        
        // Validate executable exists and is executable
        let exePath = (exe as NSString).expandingTildeInPath
        guard FileManager.default.isExecutableFile(atPath: exePath) else {
            throw MCPError.connectionFailed("Executable not found or not executable: \(exePath)")
        }
        
        let args = Array(parts.dropFirst())
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exePath)
        p.arguments = args
        
        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardInput = inPipe
        p.standardOutput = outPipe
        p.standardError = errPipe
        
        // Capture stderr for debugging
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let stderr = String(data: data, encoding: .utf8), !stderr.isEmpty {
                print("⚠️ MCP stderr: \(stderr)")
            }
        }
        
        do {
            try p.run()
        } catch {
            throw MCPError.connectionFailed("Failed to launch process: \(error.localizedDescription)")
        }
        
        self.process = p
        self.stdinPipe = inPipe
        self.stdoutPipe = outPipe
        
        // Start read loop
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consumeStdout(handle.availableData)
        }
        
        // Update connection state and start health monitoring
        connectionState.send(.connected)
        startHealthCheck()
        
        print("✅ MCP server launched: \(serverCommand)")
    }
    
    func shutdown() async {
        terminateChild()
    }
    
    func sendRequest(
        method: String,
        params: [String: Any]?,
        timeout: TimeInterval
    ) async throws -> Any? {
        // Ensure we're connected
        guard process != nil else {
            throw MCPError.notConnected
        }
        
        let id: Int = rpcQueue.sync { defer { nextId += 1 }; return nextId }
        var payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method
        ]
        if let p = params { payload["params"] = p }
        
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw MCPError.invalidResponse("Failed to serialize request: \(error.localizedDescription)")
        }
        
        guard let stdin = stdinPipe?.fileHandleForWriting else {
            throw MCPError.transportError("stdin not available")
        }
        
        let sem = DispatchSemaphore(value: 0)
        let box = ResponseBox()
        rpcQueue.sync { pending[id] = (sem, box) }
        
        // Write newline-delimited JSON for framing
        do {
            try stdin.write(contentsOf: data)
            try stdin.write(contentsOf: "\n".data(using: .utf8)!)
            try stdin.synchronize()
        } catch {
            rpcQueue.sync { _ = pending.removeValue(forKey: id) }
            throw MCPError.transportError("Failed to write request: \(error.localizedDescription)")
        }
        
        let deadline = DispatchTime.now() + timeout
        if sem.wait(timeout: deadline) == .timedOut {
            rpcQueue.sync { _ = pending.removeValue(forKey: id) }
            throw MCPError.requestTimeout(method: method)
        }
        
        // Grab and decode response
        var resultAny: Any?
        rpcQueue.sync {
            if let entry = pending.removeValue(forKey: id) {
                resultAny = entry.storage.obj
            }
        }
        
        guard let resp = resultAny as? [String: Any] else {
            return nil
        }
        
        if let error = resp["error"] as? [String: Any] {
            let msg = error["message"] as? String ?? "Unknown MCP error"
            let code = error["code"] as? Int ?? 5
            throw MCPError.serverError(code: code, message: msg)
        }
        
        return resp["result"]
    }
    
    func isHealthy() async -> Bool {
        // Don't check health if not connected
        guard process != nil else {
            return false
        }
        
        do {
            // Send a lightweight ping request
            _ = try await sendRequest(method: "ping", params: nil, timeout: healthCheckTimeout)
            consecutiveFailures = 0
            
            // Update state to connected if we were unhealthy
            if connectionState.value == .unhealthy {
                connectionState.send(.connected)
            }
            
            return true
        } catch {
            consecutiveFailures += 1
            print("⚠️ Health check failed (attempt \(consecutiveFailures)/\(maxFailures)): \(error.localizedDescription)")
            
            if consecutiveFailures >= maxFailures && connectionState.value != .unhealthy {
                connectionState.send(.unhealthy)
            }
            
            return false
        }
    }
    
    // MARK: - Private: Process Management
    
    /// Parse shell command with proper argument handling
    /// Handles quoted arguments like: node "dist/my server.js" --arg="value"
    private func parseShellCommand(_ command: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuotes = false
        var escapeNext = false
        
        for char in command {
            if escapeNext {
                current.append(char)
                escapeNext = false
                continue
            }
            
            switch char {
            case "\\":
                escapeNext = true
            case "\"":
                inQuotes.toggle()
            case " " where !inQuotes, "\t" where !inQuotes, "\n" where !inQuotes:
                if !current.isEmpty {
                    parts.append(current)
                    current = ""
                }
            default:
                current.append(char)
            }
        }
        
        if !current.isEmpty {
            parts.append(current)
        }
        
        return parts
    }
    
    private func terminateChild() {
        // Stop health checks
        stopHealthCheck()
        
        // Clear handlers first to prevent callbacks during cleanup
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        
        // Close file handles explicitly before terminating process
        if let stdin = stdinPipe?.fileHandleForWriting {
            try? stdin.close()
        }
        if let stdout = stdoutPipe?.fileHandleForReading {
            try? stdout.close()
        }
        
        // Terminate process gracefully, then forcefully if needed
        if let p = process, p.isRunning {
            p.terminate()
            
            // Wait briefly for clean shutdown
            let deadline = Date().addingTimeInterval(0.5)
            while p.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            
            // Force interrupt if still running
            if p.isRunning {
                p.interrupt()
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        // Clear references
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        
        // Update connection state
        if connectionState.value != .reconnecting {
            connectionState.send(.disconnected)
        }
    }
    
    // MARK: - Private: JSON-RPC
    
    private class ResponseBox {
        var obj: Any?
        init() {
            self.obj = nil
        }
    }
    
    private func consumeStdout(_ chunk: Data) {
        if chunk.isEmpty { return }
        rpcQueue.async {
            // Check buffer size before appending to prevent unbounded growth
            guard self.readBuffer.count < self.maxBufferSize else {
                print("⚠️ MCP read buffer exceeded \(self.maxBufferSize / 1_000_000)MB limit, resetting")
                self.readBuffer.removeAll()
                return
            }
            
            self.readBuffer.append(chunk)
            
            // Split by newlines (NDJSON)
            while let range = self.readBuffer.firstRange(of: "\n".data(using: .utf8)!) {
                let line = self.readBuffer.subdata(in: 0..<range.lowerBound)
                self.readBuffer.removeSubrange(0..<range.upperBound)
                
                // Check individual message size
                guard line.count < self.maxMessageSize else {
                    print("⚠️ Skipping oversized MCP message (\(line.count / 1_000_000)MB)")
                    continue
                }
                
                self.handleLine(line)
            }
        }
    }
    
    private func handleLine(_ line: Data) {
        guard !line.isEmpty else { return }
        guard let obj = try? JSONSerialization.jsonObject(with: line, options: []) as? [String: Any] else { return }
        guard let id = obj["id"] as? Int else { return }
        rpcQueue.sync {
            if let entry = pending[id] {
                entry.storage.obj = obj
                entry.signal.signal()
            }
        }
    }
    
    // MARK: - Private: Health Checks
    
    private func startHealthCheck() {
        // Stop any existing timer
        stopHealthCheck()
        
        // Schedule periodic health checks on the main thread
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard let self = self else { return }
                
                if !(await self.isHealthy()) {
                    await self.handleUnhealthyState()
                }
            }
        }
        
        // Ensure timer fires on common run loop modes (including tracking mode for UI)
        if let timer = healthCheckTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("✅ Health check started (interval: \(healthCheckInterval)s)")
    }
    
    private func stopHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    private func handleUnhealthyState() async {
        guard consecutiveFailures >= maxFailures else { return }
        
        print("❌ MCP client unhealthy after \(maxFailures) failures, attempting restart...")
        connectionState.send(.reconnecting)
        
        // Terminate the unhealthy process
        terminateChild()
        
        // Reset failure counter
        consecutiveFailures = 0
        
        // Attempt to relaunch
        do {
            try await initialize()
            print("✅ MCP client restarted successfully")
        } catch {
            print("❌ Failed to restart MCP client: \(error.localizedDescription)")
            connectionState.send(.disconnected)
        }
    }
}