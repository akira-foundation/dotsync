import Foundation

public struct SyncResult: Codable, Equatable {
    public var rootID: String
    public var timestamp: String
    public var pushed: Bool
    public var conflict: Bool
    public var backupBranch: String?
    public var pendingBefore: Int
    public var message: String

    public init(rootID: String, timestamp: String, pushed: Bool, conflict: Bool,
                backupBranch: String?, pendingBefore: Int, message: String) {
        self.rootID = rootID
        self.timestamp = timestamp
        self.pushed = pushed
        self.conflict = conflict
        self.backupBranch = backupBranch
        self.pendingBefore = pendingBefore
        self.message = message
    }
}

public enum State {
    public static func path(for root: Root) -> URL {
        root.expandedPath.appendingPathComponent(".git/dotsync-state.json")
    }

    public static func write(_ result: SyncResult, for root: Root) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(result).write(to: path(for: root))
    }

    public static func read(for root: Root) throws -> SyncResult? {
        let url = path(for: root)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(SyncResult.self, from: Data(contentsOf: url))
    }
}
