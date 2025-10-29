import Foundation
import AppKit
import UniformTypeIdentifiers

final class AppModel: ObservableObject {
    @Published var lastOpenedURL: URL?
    
    func openShader(completion: (URL, String) -> Void) {
        let panel = NSOpenPanel()
        if let metalUTI = UTType(filenameExtension: "metal") {
            panel.allowedContentTypes = [metalUTI]
        } else {
            panel.allowedFileTypes = ["metal"]
        }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            if let code = try? String(contentsOf: url, encoding: .utf8) {
                lastOpenedURL = url
                completion(url, code)
            }
        }
    }
    
    func reloadCurrent(completion: (URL, String) -> Void) {
        guard let url = lastOpenedURL, let code = try? String(contentsOf: url, encoding: .utf8) else { return }
        completion(url, code)
    }
}
