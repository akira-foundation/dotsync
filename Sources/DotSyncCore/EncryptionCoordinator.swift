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
        let fileManager = FileManager.default
        for relative in sensitiveFiles(in: repo) {
            let input = repo.appendingPathComponent(relative)
            let output = repo.appendingPathComponent(relative + ".age")
            guard needsEncryption(input: input, output: output) else { continue }

            let temp = output.appendingPathExtension("tmp")
            try age.encrypt(input: input, recipients: recipients, output: temp)
            let size = (try? fileManager.attributesOfItem(atPath: temp.path))?[.size] as? Int ?? 0
            guard size > 0 else {
                try? fileManager.removeItem(at: temp)
                continue
            }
            _ = try? fileManager.removeItem(at: output)
            try fileManager.moveItem(at: temp, to: output)
        }
    }

    public static func decryptAll(repo: URL, age: AgeCrypto, identity: String) throws {
        for relative in ageFiles(in: repo) {
            let input = repo.appendingPathComponent(relative)
            let output = repo.appendingPathComponent(String(relative.dropLast(4)))
            try age.decrypt(input: input, identity: identity, output: output)
            if let ageDate = modificationDate(input) {
                try? FileManager.default.setAttributes(
                    [.modificationDate: ageDate], ofItemAtPath: output.path)
            }
        }
    }

    static func needsEncryption(input: URL, output: URL) -> Bool {
        guard let ageDate = modificationDate(output) else { return true }
        guard let plainDate = modificationDate(input) else { return false }
        return plainDate > ageDate
    }

    private static func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
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
