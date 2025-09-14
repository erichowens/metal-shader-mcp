import Foundation

public protocol MCPClient {
    func writeJSON(_ object: Any, to path: String)
    func writeText(_ text: String, to path: String)
    func ensureDir(_ path: String)
}

public final class FileBridgeMCPClient: MCPClient {
    private let fm = FileManager.default

    public init() {}

    public func ensureDir(_ path: String) {
        try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    public func writeJSON(_ object: Any, to path: String) {
        do {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
            ensureDir((path as NSString).deletingLastPathComponent)
            try data.write(to: URL(fileURLWithPath: path))
        } catch {
            fputs("[MCPClient] Failed to write JSON to \(path): \(error)\n", stderr)
        }
    }

    public func writeText(_ text: String, to path: String) {
        do {
            ensureDir((path as NSString).deletingLastPathComponent)
            if fm.fileExists(atPath: path) { try fm.removeItem(atPath: path) }
            try text.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            fputs("[MCPClient] Failed to write text to \(path): \(error)\n", stderr)
        }
    }
}

public enum MCP {
    public static let shared: MCPClient = FileBridgeMCPClient()
}
