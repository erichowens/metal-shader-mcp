import Foundation

// File-bridge implementation that writes to Resources/communication/*.json
final class FileBridgeMCP: MCPBridge {
    private let commDir = "Resources/communication"

    func setShader(code: String, description: String?, noSnapshot: Bool) throws {
        var cmd: [String: Any] = [
            "action": "set_shader",
            "shader_code": code,
            "timestamp": Date().timeIntervalSince1970,
            "no_snapshot": noSnapshot
        ]
        if let description = description { cmd["description"] = description }
        try writeCommand(cmd)
    }

    func setShaderWithMeta(name: String?, description: String?, path: String?, code: String?, save: Bool, noSnapshot: Bool) throws {
        var cmd: [String: Any] = [
            "action": "set_shader_with_meta",
            "save": save,
            "no_snapshot": noSnapshot,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let name = name { cmd["name"] = name }
        if let description = description { cmd["description"] = description }
        if let path = path { cmd["path"] = path }
        if let code = code { cmd["shader_code"] = code }
        try writeCommand(cmd)
    }

    func exportFrame(description: String, time: Float?) throws {
        var cmd: [String: Any] = [
            "action": "export_frame",
            "description": description,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let time = time { cmd["time"] = time }
        try writeCommand(cmd)
    }

    func setTab(_ tab: String) throws {
        let cmd: [String: Any] = [
            "action": "set_tab",
            "tab": tab,
            "timestamp": Date().timeIntervalSince1970
        ]
        try writeCommand(cmd)
    }

    private func writeCommand(_ obj: [String: Any]) throws {
        try FileManager.default.createDirectory(atPath: commDir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted])
        try data.write(to: URL(fileURLWithPath: commDir + "/commands.json"))
    }
}