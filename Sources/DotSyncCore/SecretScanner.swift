import Foundation

public struct SecretFinding: Equatable, Sendable {
    public let file: String
    public let rule: String

    public init(file: String, rule: String) {
        self.file = file
        self.rule = rule
    }
}

public struct SecretScanReport: Equatable, Sendable {
    public let forbidden: [String]
    public let findings: [SecretFinding]

    public var isClean: Bool { forbidden.isEmpty && findings.isEmpty }
}

public enum SecretScanner {
    static let forbiddenNames: Set<String> = [".credentials.json", "credentials.json", "auth.json"]
    static let forbiddenSuffixes: [String] = [".local.json"]

    static let rules: [(name: String, pattern: String)] = [
        ("api-key", "sk-[A-Za-z0-9_-]{20,}"),
        ("github-token", "gh[pousr]_[A-Za-z0-9]{36,}"),
        ("slack-token", "xox[baprs]-[A-Za-z0-9-]{10,}"),
        ("aws-access-key", "AKIA[0-9A-Z]{16}"),
        ("private-key", "-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    ]

    public static func forbiddenTracked(_ paths: [String]) -> [String] {
        paths.filter { path in
            let name = (path as NSString).lastPathComponent
            if forbiddenNames.contains(name) { return true }
            return forbiddenSuffixes.contains { name.hasSuffix($0) }
        }
    }

    public static func scan(content: String) -> [String] {
        let range = NSRange(content.startIndex..., in: content)
        return rules.compactMap { rule in
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { return nil }
            return regex.firstMatch(in: content, range: range) != nil ? rule.name : nil
        }
    }

    public static func scanFiles(_ files: [(name: String, content: String)]) -> [SecretFinding] {
        files.flatMap { file in
            scan(content: file.content).map { SecretFinding(file: file.name, rule: $0) }
        }
    }

    public static func scanRepo(_ repo: URL) -> SecretScanReport {
        let git = Git(repo: repo)
        let tracked =
            (try? git.run(["ls-files"]).stdout
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)) ?? []

        var files: [(name: String, content: String)] = []
        for relative in tracked {
            let url = repo.appendingPathComponent(relative)
            guard let data = try? Data(contentsOf: url), data.count < 1_000_000,
                let text = String(data: data, encoding: .utf8)
            else { continue }
            files.append((name: relative, content: text))
        }

        return SecretScanReport(
            forbidden: forbiddenTracked(tracked),
            findings: scanFiles(files)
        )
    }
}
