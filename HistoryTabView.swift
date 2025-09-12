import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []
    private let baseDir = "Resources/sessions"

    struct Session: Identifiable {
        let id: String
        let path: String
        let createdAt: Date
        let snapshots: [Snapshot]
    }

    struct Snapshot: Identifiable {
        let id: String
        let jsonPath: String
        let codePath: String
        let imagePath: String?
        let timestamp: Date
        let errors: Int
        let warnings: Int
        let label: String?
    }

    init() {
        ensureBaseDir()
        reload()
    }

    func reload() {
        ensureBaseDir()
        var result: [Session] = []
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: baseDir) else {
            sessions = []
            return
        }
        for entry in entries.sorted() { // timestamped dirs
            let sessionPath = baseDir + "/" + entry
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: sessionPath, isDirectory: &isDir), isDir.boolValue {
                let sessionJson = sessionPath + "/session.json"
                let createdAt = Self.readCreatedAt(sessionJson: sessionJson)
                let snaps = Self.readSnapshots(sessionPath: sessionPath)
                result.append(Session(id: entry, path: sessionPath, createdAt: createdAt, snapshots: snaps))
            }
        }
        // Sort newest first
        sessions = result.sorted { $0.createdAt > $1.createdAt }
    }

    private func ensureBaseDir() {
        try? FileManager.default.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
    }

    private static func readCreatedAt(sessionJson: String) -> Date {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: sessionJson)),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ts = obj["created_at"] as? TimeInterval {
            return Date(timeIntervalSince1970: ts)
        }
        return Date.distantPast
    }

    private static func readSnapshots(sessionPath: String) -> [Snapshot] {
        let snapsDir = sessionPath + "/snapshots"
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: snapsDir) else { return [] }
        // Group by basename snap_XXXX
        let bases = Set(files.compactMap { name -> String? in
            if name.hasSuffix(".json") || name.hasSuffix(".metal") || name.hasSuffix(".png") {
                return String(name.split(separator: ".").first!)
            }
            return nil
        })
        var snaps: [Snapshot] = []
        for base in bases {
            let jsonPath = snapsDir + "/" + base + ".json"
            let codePath = snapsDir + "/" + base + ".metal"
            let pngPath = snapsDir + "/" + base + ".png"
            let meta = readSnapshotMeta(jsonPath: jsonPath)
            let ts = meta.timestamp
            let snap = Snapshot(id: base,
                                jsonPath: jsonPath,
                                codePath: codePath,
                                imagePath: FileManager.default.fileExists(atPath: pngPath) ? pngPath : nil,
                                timestamp: ts,
                                errors: meta.errors,
                                warnings: meta.warnings,
                                label: meta.label)
            snaps.append(snap)
        }
        // Sort by time ascending within session
        return snaps.sorted { $0.timestamp < $1.timestamp }
    }

    func createEmptySession(note: String) {
        ensureBaseDir()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = df.string(from: Date())
        let sid = "session_\(stamp)"
        let sessionDir = baseDir + "/" + sid
        let snapsDir = sessionDir + "/snapshots"
        try? FileManager.default.createDirectory(atPath: snapsDir, withIntermediateDirectories: true)
        let meta: [String: Any] = [
            "id": sid,
            "created_at": Date().timeIntervalSince1970,
            "app": "ShaderPlayground",
            "notes": note
        ]
        if let data = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: sessionDir + "/session.json"))
        }
        // touch timeline
        FileManager.default.createFile(atPath: sessionDir + "/timeline.jsonl", contents: nil)
        reload()
    }

    private static func readSnapshotMeta(jsonPath: String) -> (timestamp: Date, errors: Int, warnings: Int, label: String?) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (Date.distantPast, 0, 0, nil)
        }
        let ts = (obj["timestamp"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date.distantPast
        let errors = obj["errors"] as? Int ?? 0
        let warnings = obj["warnings"] as? Int ?? 0
        // label comes from timeline; optional, not required in meta json
        let label = obj["label"] as? String
        return (ts, errors, warnings, label)
    }
}

struct HistoryTabView: View {
    @StateObject private var store = SessionStore()
    @State private var selectedKeys: Set<String> = []
    @State private var showCompare: Bool = false
    @State private var searchText: String = ""

    var body: some View {
        NavigationView {
            if store.sessions.isEmpty {
                VStack(spacing: 12) {
                    Text("No sessions found")
                        .font(.title3)
                    Text("Open the REPL and make a change, or create an empty session.")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button(action: { store.createEmptySession(note: "manual") }) { Label("Create Empty Session", systemImage: "plus") }
                        Button(action: { store.reload() }) { Label("Reload", systemImage: "arrow.clockwise") }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            List {
                ForEach(filteredSessions()) { session in
                    Section(header: HStack {
                        Text(session.id)
                        Spacer()
                        Text(Self.fmt(session.createdAt))
                            .foregroundStyle(.secondary)
                    }) {
                        if session.snapshots.isEmpty {
                            Text("No snapshots yet").foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: true) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(filteredSnapshots(in: session)) { snap in
                                        SnapshotCard(snapshot: snap,
                                                     uniqueKey: "\(session.id)/\(snap.id)",
                                                     selectedKeys: $selectedKeys)
                                    }
                                }.padding(.vertical, 6)
                            }.frame(height: 160)
                        }
                    }
                }
            }
            .navigationTitle("Session Browser")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { store.reload() }) { Label("Reload", systemImage: "arrow.clockwise") }
                    Button(action: { showCompare = true }) { Label("Compare", systemImage: "rectangle.split.2x1") }
                        .disabled(selectedKeys.count != 2)
                        .help("Compare two selected snapshots")
                }
            }
        }
        .searchable(text: $searchText)
        .sheet(isPresented: $showCompare) { CompareSheet(selectedKeys: Array(selectedKeys), store: store) }
    }

    private func filteredSessions() -> [SessionStore.Session] {
        guard !searchText.isEmpty else { return store.sessions }
        let term = searchText.lowercased()
        return store.sessions.compactMap { s in
            let snapMatches = s.snapshots.filter { $0.id.lowercased().contains(term) || (s.id.lowercased().contains(term)) }
            if !snapMatches.isEmpty || s.id.lowercased().contains(term) {
                return SessionStore.Session(id: s.id, path: s.path, createdAt: s.createdAt, snapshots: snapMatches.isEmpty ? s.snapshots : snapMatches)
            }
            return nil
        }
    }

    private func filteredSnapshots(in session: SessionStore.Session) -> [SessionStore.Snapshot] {
        guard !searchText.isEmpty else { return session.snapshots }
        let term = searchText.lowercased()
        return session.snapshots.filter { $0.id.lowercased().contains(term) }
    }

    private static func fmt(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: d)
    }
}

struct SnapshotCard: View {
    let snapshot: SessionStore.Snapshot
    let uniqueKey: String
    @Binding var selectedKeys: Set<String>

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ThumbnailView(imagePath: snapshot.imagePath)
                    .frame(width: 140, height: 120)
                    .clipped()
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                if snapshot.errors > 0 {
                    Label("\(snapshot.errors)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .padding(4)
                        .background(.yellow.opacity(0.9))
                        .cornerRadius(4)
                        .padding(4)
                }
            }
            HStack {
                Text(snapshot.id)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Button(action: { toggleSelect() }) {
                    Image(systemName: selectedKeys.contains(uniqueKey) ? "checkmark.circle.fill" : "circle")
                        .help("Select for compare")
                }.buttonStyle(.plain)
                Button(action: openInREPL) {
                    Image(systemName: "arrow.turn.down.left")
                        .help("Open in REPL (records snapshot)")
                }.buttonStyle(.plain)
                Button(action: openInREPLSilent) {
                    Image(systemName: "eye.slash")
                        .help("Open in REPL (no snapshot)")
                }.buttonStyle(.plain)
            }
            .frame(width: 140)
        }
        .frame(width: 150)
    }

    private func toggleSelect() {
        if selectedKeys.contains(uniqueKey) { selectedKeys.remove(uniqueKey) } else { selectedKeys.insert(uniqueKey) }
    }

    private func openInREPL() {
        // Read code
        guard let code = try? String(contentsOfFile: snapshot.codePath, encoding: .utf8) else { return }
        // Write uniforms.json if snapshot meta has uniforms (optional)
        // Stepwise optional unwrapping with error handling
        if let jsonData = try? Data(contentsOf: URL(fileURLWithPath: snapshot.jsonPath)) {
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    if let uniforms = jsonObject["uniforms"] as? [String: Any] {
                        let obj: [String: Any] = ["uniforms": uniforms, "timestamp": Date().timeIntervalSince1970]
                        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]) {
                            try? data.write(to: URL(fileURLWithPath: "Resources/communication/uniforms.json"))
                        }
                    } else {
                        print("Warning: 'uniforms' key not found or not a dictionary in \(snapshot.jsonPath)")
                    }
                } else {
                    print("Warning: JSON root is not a dictionary in \(snapshot.jsonPath)")
                }
            } catch {
                print("Error parsing JSON from \(snapshot.jsonPath): \(error)")
            }
        } else {
            print("Warning: Could not read data from \(snapshot.jsonPath)")
        }
// Send set_shader via MCP bridge
        let bridge = FileBridgeMCP()
        bridge.setShader(code: code, name: nil, description: "open_snapshot \(snapshot.id)", path: nil, save: false, snapshot: true)
    }

    private func openInREPLSilent() {
        guard let code = try? String(contentsOfFile: snapshot.codePath, encoding: .utf8) else { return }
let bridge = FileBridgeMCP()
        bridge.setShader(code: code, name: nil, description: "open_snapshot_silent \(snapshot.id)", path: nil, save: false, snapshot: false)
    }
}

struct ThumbnailView: View {
    let imagePath: String?
    var body: some View {
        Group {
            if let path = imagePath, let nsimg = NSImage(contentsOfFile: path) {
                Image(nsImage: nsimg)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.black.opacity(0.1)
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct CompareSheet: View {
    let selectedKeys: [String]
    let store: SessionStore

    private func lookup(_ key: String) -> (SessionStore.Session, SessionStore.Snapshot)? {
        let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let sessionId = parts[0], snapId = parts[1]
        guard let session = store.sessions.first(where: { $0.id == sessionId }),
              let snap = session.snapshots.first(where: { $0.id == snapId }) else { return nil }
        return (session, snap)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Compare Snapshots")
                .font(.headline)
            HStack(spacing: 10) {
                ForEach(selectedKeys.prefix(2), id: \.self) { key in
                    if let (_, snap) = lookup(key) {
                        VStack(spacing: 6) {
                            ThumbnailView(imagePath: snap.imagePath)
                                .frame(width: 240, height: 200)
                                .clipped()
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                            Text("\(snap.id)")
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(.horizontal)
            HStack {
                Button("Close") {
                    if let keyWindow = NSApp.keyWindow {
                        keyWindow.endSheet(keyWindow)
                    }
                }
            }
            .padding(.bottom)
        }
        .padding()
        .frame(minWidth: 540, minHeight: 320)
    }
}

