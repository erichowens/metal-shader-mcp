import SwiftUI

struct ShaderCommands: Commands {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var commandBridge: CommandBridge
    
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Shader…") {
                commandBridge.openFromMenu()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            
            Button("Reload Current Shader") {
                commandBridge.reloadFromMenu()
            }
            .keyboardShortcut("r", modifiers: [.command])
        }
        CommandMenu("Shader") {
            Button("Reload Current") { commandBridge.reloadFromMenu() }
                .keyboardShortcut("r", modifiers: [.command])
        }
    }
}

final class CommandBridge: ObservableObject {
    var onOpen: (() -> Void)?
    var onReload: (() -> Void)?
    func openFromMenu() { onOpen?() }
    func reloadFromMenu() { onReload?() }
}
