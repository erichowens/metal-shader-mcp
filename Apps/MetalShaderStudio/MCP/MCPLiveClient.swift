import Foundation

// Live stdio JSON-RPC client for MCP tools. This wires a long-lived child process
// (MCP_SERVER_CMD) with stdin/stdout pipes, sends JSON-RPC requests, and waits for
// responses with timeouts and structured error propagation.
final class MCPLiveClient: MCPBridge {
    private let serverCommand: String
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?

    private let rpcQueue = DispatchQueue(label: "mcp.live.rpc.queue")
    private var nextId: Int = 1
    private var pending: [Int: (signal: DispatchSemaphore, storage: ResponseBox)] = [:]
    private var readBuffer = Data()

    // Config
    private let defaultTimeout: TimeInterval

    init(serverCommand: String) {
        self.serverCommand = serverCommand
        if let msStr = ProcessInfo.processInfo.environment["MCP_TIMEOUT_MS"], let ms = Double(msStr) { self.defaultTimeout = ms / 1000.0 } else { self.defaultTimeout = 8.0 }
    }

    deinit {
        terminateChild()
    }

    // MARK: - MCPBridge
    func setShader(code: String, description: String?, noSnapshot: Bool) throws {
        try ensureLaunched()
        var params: [String: Any] = ["code": code, "noSnapshot": noSnapshot]
        if let d = description { params["description"] = d }
        _ = try sendRequest(method: "set_shader", params: params, timeout: defaultTimeout)
    }

    func setShaderWithMeta(name: String?, description: String?, path: String?, code: String?, save: Bool, noSnapshot: Bool) throws {
        try ensureLaunched()
        var params: [String: Any] = ["save": save, "noSnapshot": noSnapshot]
        if let n = name { params["name"] = n }
        if let d = description { params["description"] = d }
        if let p = path { params["path"] = p }
        if let c = code { params["code"] = c }
        _ = try sendRequest(method: "set_shader_with_meta", params: params, timeout: defaultTimeout)
    }

    func exportFrame(description: String, time: Float?) throws {
        try ensureLaunched()
        var params: [String: Any] = ["description": description]
        if let t = time { params["time"] = t }
        _ = try sendRequest(method: "export_frame", params: params, timeout: defaultTimeout)
    }

    func setTab(_ tab: String) throws {
        try ensureLaunched()
        _ = try sendRequest(method: "set_tab", params: ["tab": tab], timeout: defaultTimeout)
    }

    // MARK: - Launch & Transport
    private func ensureLaunched() throws {
        if process != nil { return }

        // Naive split into executable + args. (Note: quoting is not handled.)
        let parts = serverCommand.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let exe = parts.first else {
            throw makeError(code: 1, "MCP_SERVER_CMD is empty or invalid")
        }
        let args = Array(parts.dropFirst())

        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args

        let inPipe = Pipe()
        let outPipe = Pipe()
        p.standardInput = inPipe
        p.standardOutput = outPipe
        p.standardError = Pipe() // swallow stderr or hook if needed

        try p.run()
        self.process = p
        self.stdinPipe = inPipe
        self.stdoutPipe = outPipe

        // Start read loop
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consumeStdout(handle.availableData)
        }
    }

    private func terminateChild() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        if let p = process, p.isRunning {
            p.terminate()
        }
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
    }

    // MARK: - JSON-RPC
    private struct ResponseBox { var obj: Any? }

    private func sendRequest(method: String, params: [String: Any]?, timeout: TimeInterval) throws -> Any? {
        let id: Int = rpcQueue.sync { defer { nextId += 1 }; return nextId }
        var payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method
        ]
        if let p = params { payload["params"] = p }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let stdin = stdinPipe?.fileHandleForWriting else { throw makeError(code: 3, "stdin not available") }

        let sem = DispatchSemaphore(value: 0)
        let box = ResponseBox(obj: nil)
        rpcQueue.sync { pending[id] = (sem, box) }

        // Write newline-delimited JSON for framing
        stdin.write(data)
        stdin.write("\n".data(using: .utf8)!)
        stdin.synchronizeFile()

        let deadline = DispatchTime.now() + timeout
        if sem.wait(timeout: deadline) == .timedOut {
            rpcQueue.sync { _ = pending.removeValue(forKey: id) }
            throw makeError(code: 4, "MCP request timed out: \(method)")
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
            throw makeError(code: code, msg)
        }
        return resp["result"]
    }

    private func consumeStdout(_ chunk: Data) {
        if chunk.isEmpty { return }
        rpcQueue.async {
            self.readBuffer.append(chunk)
            // Split by newlines (NDJSON)
            while let range = self.readBuffer.firstRange(of: "\n".data(using: .utf8)!) {
                let line = self.readBuffer.subdata(in: 0..<range.lowerBound)
                self.readBuffer.removeSubrange(0..<range.upperBound)
                self.handleLine(line)
            }
        }
    }

    private func handleLine(_ line: Data) {
        guard !line.isEmpty else { return }
        guard let obj = try? JSONSerialization.jsonObject(with: line, options: []) as? [String: Any] else { return }
        guard let id = obj["id"] as? Int else { return }
        rpcQueue.sync {
            if var entry = pending[id] {
                entry.storage.obj = obj
                pending[id] = entry
                entry.signal.signal()
            }
        }
    }

    // MARK: - Errors
    private func makeError(code: Int, _ message: String) -> NSError {
        return NSError(domain: "MCPLiveClient", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
