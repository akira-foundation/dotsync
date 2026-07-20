import Foundation

public struct Defaults: Codable, Equatable, Sendable {
    public var branch: String
    public var intervalSec: Int

    public init(branch: String, intervalSec: Int) {
        self.branch = branch
        self.intervalSec = intervalSec
    }
}

public struct Root: Codable, Equatable, Sendable {
    public enum Trigger: String, Codable, Sendable { case hook, scheduler }

    public var id: String
    public var path: String
    public var remote: String?
    public var branch: String?
    public var trigger: Trigger
    public var auto: Bool?
    public var intervalSec: Int?
    public var watch: Bool?

    public init(id: String, path: String, remote: String?, branch: String?,
                trigger: Trigger, auto: Bool?, intervalSec: Int?, watch: Bool?) {
        self.id = id
        self.path = path
        self.remote = remote
        self.branch = branch
        self.trigger = trigger
        self.auto = auto
        self.intervalSec = intervalSec
        self.watch = watch
    }

    public var expandedPath: URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
}

public struct Config: Codable, Equatable, Sendable {
    public var defaults: Defaults
    public var roots: [Root]

    public init(defaults: Defaults, roots: [Root]) {
        self.defaults = defaults
        self.roots = roots
    }

    public func root(id: String) -> Root? { roots.first { $0.id == id } }
    public func branch(for r: Root) -> String { r.branch ?? defaults.branch }
    public func remote(for r: Root) -> String { r.remote ?? "origin" }

    public static func load(_ url: URL) throws -> Config {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
