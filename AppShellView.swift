import SwiftUI

// Shared enum for app tabs
enum AppTab: String, Hashable, CaseIterable { case repl, library, projects, tools, history }

final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .repl
}

struct AppShellView: View {
    @EnvironmentObject var appState: AppState
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
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]) {
            try? FileManager.default.createDirectory(atPath: "Resources/communication", withIntermediateDirectories: true)
            try? data.write(to: URL(fileURLWithPath: "Resources/communication/status.json"))
        }
    }
}

// MARK: - Placeholder Views (scaffolding)
struct LibraryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Educational Shader Library")
                .font(.title2)
            Text("Curated examples, annotations, presets. Coming soon.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

