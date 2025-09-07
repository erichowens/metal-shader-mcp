import SwiftUI

struct AppShellView: View {
    @State private var selectedTab: Tab = .repl

    enum Tab: Hashable {
        case repl, library, projects, tools, history
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // REPL: Use the existing ContentView to avoid breaking behavior
            ContentView()
                .tabItem { Label("REPL", systemImage: "sparkles") }
                .tag(Tab.repl)

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(Tab.library)

            ProjectsView()
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(Tab.projects)

            MCPToolsView()
                .tabItem { Label("MCP Tools", systemImage: "wrench.and.screwdriver") }
                .tag(Tab.tools)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)
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

struct HistoryView: View {
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

