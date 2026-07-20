import Foundation

public enum EncryptionCoordinator {
    static let sensitiveNames: Set<String> = ["auth.json", ".credentials.json", "credentials.json"]
    static let sensitiveSuffixes = [".local.json"]

    public static func isSensitive(_ name: String) -> Bool {
        sensitiveNames.contains(name) || sensitiveSuffixes.contains { name.hasSuffix($0) }
    }

    public static func sensitiveFiles(in repo: URL) -> [String] {
        scan(repo) { isSensitive(($0 as NSString).lastPathComponent) }
    }

    public static func ageFiles(in repo: URL) -> [String] {
        scan(repo) { $0.hasSuffix(".age") }
    }

    public static func encryptAll(repo: URL, age: AgeCrypto, recipients: [String]) throws {
        for relative in sensitiveFiles(in: repo) {
            try age.encrypt(
                input: repo.appendingPathComponent(relative),
                recipients: recipients,
                output: repo.appendingPathComponent(relative + ".age"))
        }
    }

    public static func decryptAll(repo: URL, age: AgeCrypto, identity: String) throws {
        for relative in ageFiles(in: repo) {
            try age.decrypt(
                input: repo.appendingPathComponent(relative),
                identity: identity,
                output: repo.appendingPathComponent(String(relative.dropLast(4))))
        }
    }

    private static func scan(_ repo: URL, match: (String) -> Bool) -> [String] {
        let fileManager = FileManager.default
        guard
            let enumerator = fileManager.enumerator(
                at: repo, includingPropertiesForKeys: [.isDirectoryKey])
        else { return [] }

        let base = repo.resolvingSymlinksInPath().path
        var result: [String] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if name == ".git" || name == ".dotsync-age" {
                enumerator.skipDescendants()
                continue
            }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true { continue }
            let path = url.resolvingSymlinksInPath().path
            let relative =
                path.hasPrefix(base + "/") ? String(path.dropFirst(base.count + 1)) : name
            if match(relative) { result.append(relative) }
        }
        return result.sorted()
    }
}
