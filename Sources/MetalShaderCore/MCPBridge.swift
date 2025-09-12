import Foundation

public protocol MCPBridge {
    func setShader(code: String, name: String?, description: String?, path: String?, save: Bool, snapshot: Bool)
    func exportFrame(description: String, time: Float?)
}

public final class FileBridgeMCP: MCPBridge {
    private let fm = FileManager.default
    private let dir = "Resources/communication"

    public init() {
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    public func setShader(code: String, name: String?, description: String?, path: String?, save: Bool, snapshot: Bool) {
        var payload: [String: Any] = [
            "action": (name != nil || description != nil || path != nil) ? "set_shader_with_meta" : "set_shader",
            "shader_code": code,
            "timestamp": Date().timeIntervalSince1970,
            "no_snapshot": !snapshot
        ]
        if let name = name { payload["name"] = name }
        if let description = description { payload["description"] = description }
        if let p = path { payload["path"] = p }
        payload["save"] = save
        writeJSON(payload, to: dir + "/commands.json")
    }

    public func exportFrame(description: String, time: Float?) {
        var payload: [String: Any] = [
            "action": "export_frame",
            "description": description,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let t = time { payload["time"] = t }
        writeJSON(payload, to: dir + "/commands.json")
    }

    private func writeJSON(_ obj: [String: Any], to path: String) {
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}