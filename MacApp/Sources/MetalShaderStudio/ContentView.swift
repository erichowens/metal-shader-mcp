import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appModel: AppModel
    @StateObject private var renderer = MetalShaderRenderer()
    @State private var builtInShaders: [ShaderEntry] = []
    @State private var selectedShader: ShaderEntry?
    @State private var compileError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar area with shader picker
            HStack(spacing: 12) {
                Text("Shader:")
                Picker("Shader", selection: $selectedShader) {
                    ForEach(builtInShaders) { entry in
                        Text(entry.title).tag(Optional(entry))
                    }
                }
                .frame(width: 320)
                Button("Open Shader…") { appModel.openShader { url, code in
                    let entry = ShaderEntry(title: url.deletingPathExtension().lastPathComponent, path: url.path, code: code)
                    self.selectedShader = entry
                    applyShader(entry)
                } }
                Spacer()
                Text("FPS: \(Int(renderer.fps))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.thinMaterial)
            
            Divider()
            
            // Metal render view
            MetalView(renderer: renderer)
                .frame(minWidth: 800, minHeight: 520)
                .background(Color.black)
        }
        .onAppear {
            loadBuiltIns()
            NotificationCenter.default.addObserver(forName: .applyOpenedShader, object: nil, queue: .main) { note in
                if let dict = note.object as? [String: Any], let url = dict["url"] as? URL, let code = dict["code"] as? String {
                    let entry = ShaderEntry(title: url.deletingPathExtension().lastPathComponent, path: url.path, code: code)
                    self.selectedShader = entry
                    applyShader(entry)
                }
            }
        }
        .alert("Shader Compile Error", isPresented: Binding(get: { compileError != nil }, set: { _ in compileError = nil })) {
            Button("OK") { compileError = nil }
        } message: {
            Text(compileError ?? "")
        }
        .onChange(of: selectedShader) { entry in
            guard let entry else { return }
            applyShader(entry)
        }
    }
    
    private func loadBuiltIns() {
        // Find shaders directory relative to project root
        let projectRoot = findProjectRoot()
        let dir = (projectRoot as NSString).appendingPathComponent("shaders")
        
        print("DEBUG: Looking for shaders in: \(dir)")
        print("DEBUG: Directory exists: \(FileManager.default.fileExists(atPath: dir))")
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else {
            print("DEBUG: Could not read directory")
            return
        }
        
        print("DEBUG: Found \(files.count) files")
        
        var entries: [ShaderEntry] = []
        for fn in files where fn.hasSuffix(".metal") {
            let full = (dir as NSString).appendingPathComponent(fn)
            if let code = try? String(contentsOfFile: full) {
                let title = (fn as NSString).deletingPathExtension
                entries.append(ShaderEntry(title: title, path: full, code: code))
                print("DEBUG: Loaded shader: \(title)")
            }
        }
        
        self.builtInShaders = entries.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        print("DEBUG: Total shaders loaded: \(builtInShaders.count)")
        
        if let first = self.builtInShaders.first {
            self.selectedShader = first
            applyShader(first)
        }
    }
    
    private func findProjectRoot() -> String {
        // When running as .app bundle, walk up from executable path to find project root
        if let execPath = Bundle.main.executablePath {
            var current = (execPath as NSString).deletingLastPathComponent
            // Walk up from .app/Contents/MacOS
            for _ in 0..<20 {
                if FileManager.default.fileExists(atPath: (current as NSString).appendingPathComponent("Package.swift")) {
                    print("DEBUG: Found project root at: \(current)")
                    return current
                }
                current = (current as NSString).deletingLastPathComponent
            }
        }
        // Fallback to looking from current directory
        var current = FileManager.default.currentDirectoryPath
        print("DEBUG: Current directory: \(current)")
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath: (current as NSString).appendingPathComponent("Package.swift")) {
                return current
            }
            current = (current as NSString).deletingLastPathComponent
        }
        // Last resort: hardcoded path (only for development)
        return "/Users/erichowens/coding/metal-shader-mcp"
    }
    
    private func applyShader(_ entry: ShaderEntry) {
        renderer.updateShader(entry.code) { err in
            compileError = err
        }
    }
    
    private func openShaderLegacy() {} // handled via AppModel to support menu commands
}

struct ShaderEntry: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let path: String
    let code: String
}
