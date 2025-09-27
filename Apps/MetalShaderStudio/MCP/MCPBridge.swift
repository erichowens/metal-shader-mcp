import Foundation
import SwiftUI

// Protocol defining the minimal MCP surface area used by the current UI.
protocol MCPBridge {
    func setShader(code: String, description: String?, noSnapshot: Bool) throws
    func setShaderWithMeta(name: String?, description: String?, path: String?, code: String?, save: Bool, noSnapshot: Bool) throws
    func exportFrame(description: String, time: Float?) throws
    func setTab(_ tab: String) throws
}

// Observable container so we can inject via Environment and swap implementations.
final class BridgeContainer: ObservableObject {
    let bridge: MCPBridge
    init(bridge: MCPBridge) { self.bridge = bridge }
}

enum BridgeFactory {
    static func make() -> MCPBridge {
        // If an explicit live server command is provided, prefer attempting live.
        if let cmd = ProcessInfo.processInfo.environment["MCP_SERVER_CMD"], !cmd.trimmingCharacters(in: .whitespaces).isEmpty {
            return MCPLiveClient(serverCommand: cmd)
        }
        // Respect explicit file-bridge opt-in
        if let useFile = ProcessInfo.processInfo.environment["USE_FILE_BRIDGE"], useFile.lowercased() == "true" {
            return FileBridgeMCP()
        }
        // Default today: file bridge (until live client is integrated fully)
        return FileBridgeMCP()
    }
}