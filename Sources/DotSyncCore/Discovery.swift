import Foundation

public enum Discovery {
    public static let known = [
        "~/.claude", "~/.codex", "~/.gemini", "~/.aider", "~/.continue", "~/.cursor",
    ]

    public static func candidatePaths(_ userPaths: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for path in known + userPaths where seen.insert(path).inserted {
            result.append(path)
        }
        return result
    }
}
