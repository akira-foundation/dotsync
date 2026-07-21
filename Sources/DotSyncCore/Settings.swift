import Foundation

public struct GitHubSettings: Codable, Equatable, Sendable {
    public var host: String
    public var account: String?
    public var visibility: String
    public var repoNameTemplate: String
    public var autoCreateRemote: Bool

    public init(
        host: String = "github.com", account: String? = nil,
        visibility: String = "private", repoNameTemplate: String = "dotsync-{id}",
        autoCreateRemote: Bool = false
    ) {
        self.host = host
        self.account = account
        self.visibility = visibility
        self.repoNameTemplate = repoNameTemplate
        self.autoCreateRemote = autoCreateRemote
    }
}

public struct DiscoverySettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var autoAdd: Bool
    public var paths: [String]
    public var ignored: [String]

    public init(
        enabled: Bool = true, autoAdd: Bool = true,
        paths: [String] = ["~/.claude", "~/.codex"], ignored: [String] = []
    ) {
        self.enabled = enabled
        self.autoAdd = autoAdd
        self.paths = paths
        self.ignored = ignored
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, autoAdd, paths, ignored
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        autoAdd = try container.decodeIfPresent(Bool.self, forKey: .autoAdd) ?? true
        paths =
            try container.decodeIfPresent([String].self, forKey: .paths) ?? [
                "~/.claude", "~/.codex",
            ]
        ignored = try container.decodeIfPresent([String].self, forKey: .ignored) ?? []
    }
}

public struct AutoSyncSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var intervalSec: Int
    public var watch: Bool

    public init(enabled: Bool = true, intervalSec: Int = 300, watch: Bool = false) {
        self.enabled = enabled
        self.intervalSec = intervalSec
        self.watch = watch
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, intervalSec, watch
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        intervalSec = try container.decodeIfPresent(Int.self, forKey: .intervalSec) ?? 300
        watch = try container.decodeIfPresent(Bool.self, forKey: .watch) ?? false
    }
}

public struct GuardSettings: Codable, Equatable, Sendable {
    public var requirePrivate: Bool
    public var secretScan: Bool
    public var blockOnTrackedSecrets: Bool
    public var allowlistPaths: [String]

    public init(
        requirePrivate: Bool = true, secretScan: Bool = true,
        blockOnTrackedSecrets: Bool = true, allowlistPaths: [String] = []
    ) {
        self.requirePrivate = requirePrivate
        self.secretScan = secretScan
        self.blockOnTrackedSecrets = blockOnTrackedSecrets
        self.allowlistPaths = allowlistPaths
    }

    private enum CodingKeys: String, CodingKey {
        case requirePrivate, secretScan, blockOnTrackedSecrets, allowlistPaths
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requirePrivate = try container.decodeIfPresent(Bool.self, forKey: .requirePrivate) ?? true
        secretScan = try container.decodeIfPresent(Bool.self, forKey: .secretScan) ?? true
        blockOnTrackedSecrets =
            try container.decodeIfPresent(Bool.self, forKey: .blockOnTrackedSecrets) ?? true
        allowlistPaths = try container.decodeIfPresent([String].self, forKey: .allowlistPaths) ?? []
    }
}

public struct EncryptionSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var host: String
    public var recipient: String?

    public init(enabled: Bool = false, host: String = "", recipient: String? = nil) {
        self.enabled = enabled
        self.host = host
        self.recipient = recipient
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, host, recipient
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
        recipient = try container.decodeIfPresent(String.self, forKey: .recipient)
    }
}

public struct Settings: Codable, Equatable, Sendable {
    public var github: GitHubSettings
    public var discovery: DiscoverySettings
    public var guards: GuardSettings
    public var autosync: AutoSyncSettings
    public var encryption: EncryptionSettings
    public var launchAtLogin: Bool

    public init(
        github: GitHubSettings = GitHubSettings(),
        discovery: DiscoverySettings = DiscoverySettings(),
        guards: GuardSettings = GuardSettings(),
        autosync: AutoSyncSettings = AutoSyncSettings(),
        encryption: EncryptionSettings = EncryptionSettings(),
        launchAtLogin: Bool = false
    ) {
        self.github = github
        self.discovery = discovery
        self.guards = guards
        self.autosync = autosync
        self.encryption = encryption
        self.launchAtLogin = launchAtLogin
    }

    private enum CodingKeys: String, CodingKey {
        case github, discovery, guards, autosync, encryption, launchAtLogin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        github =
            try container.decodeIfPresent(GitHubSettings.self, forKey: .github) ?? GitHubSettings()
        discovery =
            try container.decodeIfPresent(DiscoverySettings.self, forKey: .discovery)
            ?? DiscoverySettings()
        guards =
            try container.decodeIfPresent(GuardSettings.self, forKey: .guards) ?? GuardSettings()
        autosync =
            try container.decodeIfPresent(AutoSyncSettings.self, forKey: .autosync)
            ?? AutoSyncSettings()
        encryption =
            try container.decodeIfPresent(EncryptionSettings.self, forKey: .encryption)
            ?? EncryptionSettings()
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    }

    public static func load(_ url: URL) throws -> Settings {
        guard FileManager.default.fileExists(atPath: url.path) else { return Settings() }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Settings.self, from: data)
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    public func repoName(for id: String) -> String {
        github.repoNameTemplate.replacingOccurrences(of: "{id}", with: id)
    }
}
