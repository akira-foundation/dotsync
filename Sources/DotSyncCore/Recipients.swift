import Foundation

public struct Recipient: Codable, Equatable, Sendable {
    public var host: String
    public var publicKey: String
    public var created: String
    public var lastSeen: String

    public init(host: String, publicKey: String, created: String, lastSeen: String) {
        self.host = host
        self.publicKey = publicKey
        self.created = created
        self.lastSeen = lastSeen
    }
}

public enum Recipients {
    public static func directory(_ repo: URL) -> URL {
        repo.appendingPathComponent(".dotsync-age/recipients")
    }

    public static func load(_ repo: URL) -> [Recipient] {
        let dir = directory(repo)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return []
        }
        let decoder = JSONDecoder()
        return names.filter { $0.hasSuffix(".json") }.sorted().compactMap { name in
            guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else {
                return nil
            }
            return try? decoder.decode(Recipient.self, from: data)
        }
    }

    public static func publicKeys(_ repo: URL) -> [String] {
        load(repo).map(\.publicKey)
    }

    public static func upsert(_ recipient: Recipient, in repo: URL) throws {
        let dir = directory(repo)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(recipient)
            .write(to: dir.appendingPathComponent("\(recipient.host).json"), options: .atomic)
    }

    public static func remove(host: String, in repo: URL) throws {
        try FileManager.default.removeItem(
            at: directory(repo).appendingPathComponent("\(host).json"))
    }
}
