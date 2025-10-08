import Foundation

public struct ShaderMetadata: Codable {
    public var name: String
    public var description: String
    public var path: String?

    public init(name: String, description: String, path: String?) {
        self.name = name
        self.description = description
        self.path = path
    }

    public static func from(code: String, path: String?) -> ShaderMetadata {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        var title = ""
        var desc = ""
        if let startRange = trimmed.range(of: "/**"),
           let endRange = trimmed.range(of: "*/", range: startRange.upperBound..<trimmed.endIndex) {
            let doc = String(trimmed[startRange.upperBound..<endRange.lowerBound])
            let lines = doc.split(separator: "\n").map { line -> String in
                var s = String(line)
                if s.trimmingCharacters(in: .whitespaces).hasPrefix("*") {
                    if let starRange = s.range(of: "*") {
                        s.removeSubrange(starRange)
                    }
                }
                return s.trimmingCharacters(in: .whitespaces)
            }
            var i = 0
            while i < lines.count && lines[i].isEmpty { i += 1 }
            if i < lines.count { title = lines[i]; i += 1 }
            var descLines: [String] = []
            while i < lines.count {
                let l = lines[i]
                if l.isEmpty { break }
                descLines.append(l)
                i += 1
            }
            desc = descLines.joined(separator: " ")
        }
        if title.isEmpty { title = "Untitled Shader" }
        return ShaderMetadata(name: title, description: desc, path: path)
    }
}
