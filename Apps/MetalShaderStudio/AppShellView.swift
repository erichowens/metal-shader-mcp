import SwiftUI

// Shared enum for app tabs
enum AppTab: String, Hashable, CaseIterable { case repl, library, projects, tools, history }

final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .repl
}

struct AppShellView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var bridgeContainer: BridgeContainer
    let initialTab: AppTab

    init(initialTab: AppTab = .repl) {
        self.initialTab = initialTab
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // REPL: Use the existing ContentView to avoid breaking behavior
            ContentView()
                .tabItem { Label("REPL", systemImage: "sparkles") }
                .tag(AppTab.repl)

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(AppTab.library)

            ProjectsView()
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(AppTab.projects)

            MCPToolsView()
                .tabItem { Label("MCP Tools", systemImage: "wrench.and.screwdriver") }
                .tag(AppTab.tools)

            HistoryTabView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.history)
        }
        .onAppear {
            // Set initial tab once at startup
            if AppTab.allCases.contains(initialTab) {
                appState.selectedTab = initialTab
            }
            writeSelectedTabStatus()
        }
        .onChange(of: appState.selectedTab) { _ in
            writeSelectedTabStatus()
        }
    }

    private func writeSelectedTabStatus() {
        let obj: [String: Any] = [
            "current_tab": appState.selectedTab.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        writeJSONSafely(obj, to: "Resources/communication/status.json")
    }
    
    private func writeJSONSafely(_ obj: Any, to path: String) {
        let dir = (path as NSString).deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted])
            try data.write(to: URL(fileURLWithPath: path))
        } catch {
            // Non-fatal: log to console for now
            print("Failed to write JSON to \(path): \(error)")
        }
    }
}

// MARK: - Placeholder Views (scaffolding)
import AppKit
import Metal
import MetalKit
import MetalShaderCore

struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var entries: [LibraryEntry] = []
    @EnvironmentObject var bridgeContainer: BridgeContainer
    @State private var isLoading = false
    private let shadersDir = "shaders"
    private let commandFile = "Resources/communication/commands.json"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Shader Library").font(.title2).bold()
                Spacer()
                Button("Refresh") { loadEntries() }
            }
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass").font(.largeTitle)
                    Text("No shaders found").font(.headline)
                    Text("Place .metal files under ./shaders").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    let columns = [GridItem(.adaptive(minimum: 240), spacing: 16)]
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(entries) { entry in
                            LibraryCard(entry: entry) {
                                open(entry: entry)
                            }
                        }
                    }.padding(8)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadEntries() }
    }

    private func loadEntries() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            var result: [LibraryEntry] = []
            if let files = try? FileManager.default.contentsOfDirectory(atPath: shadersDir) {
                for fn in files where fn.hasSuffix(".metal") {
                    let full = shadersDir + "/" + fn
                    guard let code = try? String(contentsOfFile: full) else { continue }
                    var meta = ShaderMetadata.from(code: code, path: full)
                    if meta.name.isEmpty { meta.name = (fn as NSString).deletingPathExtension }
                    let thumb = ThumbnailRenderer.shared.renderThumbnail(from: code, width: 256, height: 256)
                    result.append(LibraryEntry(path: full, meta: meta, thumbnail: thumb))
                }
            }
            DispatchQueue.main.async {
                self.entries = result.sorted { $0.meta.name.localizedCaseInsensitiveCompare($1.meta.name) == .orderedAscending }
                self.isLoading = false
            }
        }
    }

    private func open(entry: LibraryEntry) {
        // Prefer MCP bridge. Fall back to file-bridge implementation internally.
        let code = (try? String(contentsOfFile: entry.path))
        do {
            try bridgeContainer.bridge.setShaderWithMeta(
                name: entry.meta.name,
                description: entry.meta.description,
                path: entry.path,
                code: code,
                save: false,
                noSnapshot: false
            )
            try? bridgeContainer.bridge.setTab("repl")
        } catch {
            // As a safety net, preserve old behavior if an unexpected error occurs.
            var obj: [String: Any] = [
                "action": "set_shader_with_meta",
                "name": entry.meta.name,
                "description": entry.meta.description,
                "path": entry.path,
                "save": false,
                "no_snapshot": false
            ]
            if let code = code { obj["shader_code"] = code }
            writeJSONSafely(obj, to: commandFile)
        }
        // Switch to REPL tab in UI
        appState.selectedTab = .repl
    }

    private func writeJSONSafely(_ obj: Any, to path: String) {
        let dir = (path as NSString).deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted])
            try data.write(to: URL(fileURLWithPath: path))
        } catch {
            print("Failed to write JSON to \(path): \(error)")
        }
    }
}

private struct LibraryEntry: Identifiable {
    let id = UUID()
    let path: String
    var meta: ShaderMetadata
    var thumbnail: NSImage?
}

private struct LibraryCard: View {
    let entry: LibraryEntry
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let img = entry.thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(height: 140)
                    .clipped()
                    .cornerRadius(8)
            } else {
                ZStack {
                    Rectangle().fill(Color.gray.opacity(0.15)).cornerRadius(8)
                    ProgressView()
                }.frame(height: 140)
            }
            Text(entry.meta.name).font(.headline).lineLimit(1)
            if !entry.meta.description.isEmpty {
                Text(entry.meta.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack {
                Text((entry.path as NSString).lastPathComponent)
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Open", action: onOpen)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.2)))
    }
}

struct ProjectsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Projects")
                .font(.title2)
            Text("Track snapshots, variants, and generational progress. Coming soon.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MCPToolsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("MCP Tool Explorer")
                .font(.title2)
            Text("Browse tools, view JSON schemas, run tools with arguments. Coming soon.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HistoryPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("History")
                .font(.title2)
            Text("Timeline of edits, tool invocations, and screenshots. Coming soon.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

