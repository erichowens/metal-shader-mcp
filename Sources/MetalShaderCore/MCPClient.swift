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
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]) {
            ensureDir((path as NSString).deletingLastPathComponent)
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    public func writeText(_ text: String, to path: String) {
        ensureDir((path as NSString).deletingLastPathComponent)
        // Replace existing file
        if fm.fileExists(atPath: path) { _ = try? fm.removeItem(atPath: path) }
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

public enum MCP {
    public static let shared: MCPClient = FileBridgeMCPClient()
}
