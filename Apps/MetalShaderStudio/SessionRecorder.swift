import Foundation
import CryptoKit
import Combine
import SwiftUI

final class SessionRecorder: ObservableObject {
    private let baseDir = "Resources/sessions"
    private(set) var sessionId: String
    private let sessionDir: String
    private let snapshotsDir: String
    private var snapshotCounter: Int = 0
    private let fileManager = FileManager.default

    init() {
        // Create a new session directory with timestamp
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = df.string(from: Date())
        self.sessionId = "session_\(stamp)"
        self.sessionDir = "\(baseDir)/\(sessionId)"
        self.snapshotsDir = "\(sessionDir)/snapshots"
        try? fileManager.createDirectory(atPath: snapshotsDir, withIntermediateDirectories: true)
        // Write session.json
        let sessionMeta: [String: Any] = [
            "id": sessionId,
            "created_at": Date().timeIntervalSince1970,
            "app": "ShaderPlayground",
            "notes": "Auto-created session"
        ]
        writeJSON(sessionMeta, to: "\(sessionDir)/session.json")
    }

    func recordSnapshot(code: String, renderer: MetalShaderRenderer, label: String? = nil, uniforms: [String: Any]? = nil) {
        snapshotCounter += 1
        let snapId = String(format: "snap_%04d", snapshotCounter)
        let codePath = "\(snapshotsDir)/\(snapId).metal"
        try? code.write(toFile: codePath, atomically: true, encoding: .utf8)

        // Hash code for identity
        let codeHash = Self.sha256Hex(of: code)

        // Ask renderer to export a frame with a unique description
        let exportDesc = "\(sessionId)_\(snapId)"
        renderer.exportFrame(description: exportDesc)

        // Poll Resources/exports to find the output PNG and copy it into the session
        let exportedPath = waitForLatestExport(matching: exportDesc, timeoutSec: 3.0)
        var sessionImagePath: String? = nil
        if let exportedPath = exportedPath {
            let dest = "\(snapshotsDir)/\(snapId).png"
            do { try fileManager.copyItem(atPath: exportedPath, toPath: dest); sessionImagePath = dest } catch {
                // If already exists, overwrite
                _ = try? fileManager.removeItem(atPath: dest)
                _ = try? fileManager.copyItem(atPath: exportedPath, toPath: dest)
                sessionImagePath = dest
            }
        }

        // Read last compilation errors if available
        var errCount = 0
        var warnCount = 0
        if let data = try? Data(contentsOf: URL(fileURLWithPath: "Resources/communication/compilation_errors.json")),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let arr = obj["errors"] as? [Any] { errCount = arr.count }
            if let arr = obj["warnings"] as? [Any] { warnCount = arr.count }
        }

        // Build snapshot metadata
        var meta: [String: Any] = [
            "id": snapId,
            "timestamp": Date().timeIntervalSince1970,
            "code_hash": codeHash,
            "code_path": codePath,
            "image_path": sessionImagePath ?? NSNull(),
            "errors": errCount,
            "warnings": warnCount
        ]
        if let uniforms = uniforms { meta["uniforms"] = uniforms }
        writeJSON(meta, to: "\(snapshotsDir)/\(snapId).json")

        // Append to session timeline jsonl
        let timelineEntry: [String: Any] = [
            "event": "snapshot",
            "id": snapId,
            "label": label ?? "",
            "image": sessionImagePath ?? "",
            "time": Date().timeIntervalSince1970
        ]
        appendJSONLine(timelineEntry, to: "\(sessionDir)/timeline.jsonl")
    }

    func recordEvent(_ name: String, payload: [String: Any] = [:]) {
        var entry: [String: Any] = ["event": name, "time": Date().timeIntervalSince1970]
        payload.forEach { entry[$0.key] = $0.value }
        appendJSONLine(entry, to: "\(sessionDir)/timeline.jsonl")
    }

    // MARK: - Helpers
    private func writeJSON(_ obj: [String: Any], to path: String) {
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    private func appendJSONLine(_ obj: [String: Any], to path: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []) else { return }
        if !fileManager.fileExists(atPath: path) { fileManager.createFile(atPath: path, contents: nil) }
        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
            if let newlineData = "\n".data(using: .utf8) {
                handle.write(newlineData)
            }
        }
    }

    private func waitForLatestExport(matching desc: String, timeoutSec: TimeInterval) -> String? {
        let dir = "Resources/screenshots"
        let start = Date()
        while Date().timeIntervalSince(start) < timeoutSec {
            if let path = latestPNG(in: dir, containing: desc) { return path }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return nil
    }

    private func latestPNG(in dir: String, containing token: String) -> String? {
        guard let items = try? fileManager.contentsOfDirectory(atPath: dir) else { return nil }
        let matches = items.filter { $0.hasSuffix(".png") && $0.contains(token) }
        guard matches.count > 0 else { return nil }
        let urls = matches.map { URL(fileURLWithPath: "\(dir)/\($0)") }
        let sorted = urls.sorted { (a, b) -> Bool in
            let at = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let bt = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return at > bt
        }
        return sorted.first?.path
    }

    private static func sha256Hex(of text: String) -> String {
        let data = Data(text.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
