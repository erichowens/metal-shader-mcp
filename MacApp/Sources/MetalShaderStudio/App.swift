import SwiftUI
import AppKit

@main
struct MetalShaderStudioApp: App {
@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appModel = AppModel()
    @StateObject var commandBridge = CommandBridge()

    var body: some Scene {
        WindowGroup("Metal Shader Studio") {
            ContentView()
                .environmentObject(appModel)
                .environmentObject(commandBridge)
                .onAppear {
                    // Wire menu commands to view behavior
                    commandBridge.onOpen = { [weak appModel] in
                        appModel?.openShader { url, code in
                            NotificationCenter.default.post(name: .applyOpenedShader, object: ["url": url, "code": code])
                        }
                    }
                    commandBridge.onReload = { [weak appModel] in
                        appModel?.reloadCurrent { url, code in
                            NotificationCenter.default.post(name: .applyOpenedShader, object: ["url": url, "code": code])
                        }
                    }
                }
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            ShaderCommands()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
