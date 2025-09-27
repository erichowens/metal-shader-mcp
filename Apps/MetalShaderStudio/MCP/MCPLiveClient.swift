import Foundation

// Skeleton of a stdio-based MCP client. For now, it validates configuration and returns
// clear errors if a live server is not available. This will be expanded in Epic 1.
final class MCPLiveClient: MCPBridge {
    private let serverCommand: String
    private var launched: Bool = false

    init(serverCommand: String) {
        self.serverCommand = serverCommand
    }

    private func ensureLaunched() throws {
        // Minimal validation: confirm that the command binary exists (first token)
        // Full stdio JSON-RPC wiring will be added next.
        let parts = serverCommand.split(separator: " ")
        guard let bin = parts.first else {
            throw NSError(domain: "MCPLiveClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "MCP_SERVER_CMD is empty or invalid"])
        }
        let which = Process()
        which.launchPath = "/usr/bin/which"
        which.arguments = [String(bin)]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = Pipe()
        try which.run()
        which.waitUntilExit()
        if which.terminationStatus != 0 {
            throw NSError(domain: "MCPLiveClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "MCP server binary not found in PATH: \(bin)"])
        }
        launched = true // placeholder until we wire persistent Process + pipes
    }

    func setShader(code: String, description: String?, noSnapshot: Bool) throws {
        try ensureLaunched()
        throw NSError(domain: "MCPLiveClient", code: 100, userInfo: [NSLocalizedDescriptionKey: "Live MCP not yet wired: setShader"])
    }

    func setShaderWithMeta(name: String?, description: String?, path: String?, code: String?, save: Bool, noSnapshot: Bool) throws {
        try ensureLaunched()
        throw NSError(domain: "MCPLiveClient", code: 101, userInfo: [NSLocalizedDescriptionKey: "Live MCP not yet wired: setShaderWithMeta"])
    }

    func exportFrame(description: String, time: Float?) throws {
        try ensureLaunched()
        throw NSError(domain: "MCPLiveClient", code: 102, userInfo: [NSLocalizedDescriptionKey: "Live MCP not yet wired: exportFrame"])
    }

    func setTab(_ tab: String) throws {
        try ensureLaunched()
        throw NSError(domain: "MCPLiveClient", code: 103, userInfo: [NSLocalizedDescriptionKey: "Live MCP not yet wired: setTab"])
    }
}