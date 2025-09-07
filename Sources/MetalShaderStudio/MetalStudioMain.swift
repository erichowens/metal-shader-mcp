import SwiftUI
import AppKit
import MetalKit

// Entry point for MetalStudioMCP Enhanced

@main
struct MetalStudioApp: App {
    @StateObject private var workspace = WorkspaceManager.shared
    
    var body: some Scene {
        WindowGroup("Metal Shader Studio MCP") {
            ContentView()
                .environmentObject(workspace)
                .frame(minWidth: 1200, minHeight: 800)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandMenu("File") {
                Button("New Shader") {
                    workspace.addShaderTab()
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Divider()
                
                Button("Save Project") {
                    // TODO: Implement save
                }
                .keyboardShortcut("s", modifiers: [.command])
                
                Button("Load Project") {
                    // TODO: Implement load
                }
                .keyboardShortcut("o", modifiers: [.command])
                
                Divider()
                
                Button("Export Shader...") {
                    // Export functionality
                }
                .keyboardShortcut("e", modifiers: [.command])
            }
            
            CommandMenu("View") {
                Button(workspace.isPlaying ? "Pause" : "Play") {
                    workspace.isPlaying.toggle()
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Divider()
                
                Button("Toggle Performance Overlay") {
                    // TODO: Toggle performance overlay
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            
            CommandMenu("Shader") {
                Button("Compile") {
                    workspace.compileCurrentShader()
                }
                .keyboardShortcut("b", modifiers: [.command])
                
                Button("Extract Parameters") {
                    workspace.extractParametersFromShader()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Reset Parameters") {
                    workspace.resetParameters()
                }
            }
        }
    }
}

let defaultShaderContent = """
fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    constant float &time [[buffer(0)]],
    constant float2 &resolution [[buffer(1)]],
    constant float2 &mouse [[buffer(2)]]
) {
    float2 uv = (in.position.xy - 0.5 * resolution) / min(resolution.x, resolution.y);
    
    // Create animated gradient
    float3 col = 0.5 + 0.5 * cos(time + uv.xyx + float3(0, 2, 4));
    
    return float4(col, 1.0);
}
"""