import Foundation

public struct HistoryEntry: Equatable, Sendable, Identifiable {
    public let hash: String
    public let timestamp: String
    public let subject: String

    public var id: String { hash }

    public init(hash: String, timestamp: String, subject: String) {
        self.hash = hash
        self.timestamp = timestamp
        self.subject = subject
    }
}

public enum History {
    static let separator = "\u{1f}"

    public static func recent(repo: URL, limit: Int = 5) -> [HistoryEntry] {
        let format = "%H\(separator)%cI\(separator)%s"
        guard
            let result = try? Git(repo: repo).run([
                "log", "--pretty=format:\(format)", "-n", "\(limit)",
            ]), result.ok
        else { return [] }
        return parse(result.stdout)
    }

    static func parse(_ output: String) -> [HistoryEntry] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line in
                let parts = line.components(separatedBy: separator)
                guard parts.count == 3 else { return nil }
                return HistoryEntry(hash: parts[0], timestamp: parts[1], subject: parts[2])
            }
    }
}
