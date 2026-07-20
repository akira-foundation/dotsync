import Foundation

public enum MergeDrivers {
    public static func scriptURL() -> URL {
        Bundle.module.url(forResource: "json-merge", withExtension: "sh")!
    }

    @discardableResult
    public static func install(binDir: URL) throws -> URL {
        try FileManager.default.createDirectory(
            at: binDir, withIntermediateDirectories: true)
        let dest = binDir.appendingPathComponent("json-merge.sh")
        let data = try Data(contentsOf: scriptURL())
        try data.write(to: dest)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: dest.path)
        return dest
    }

    public static func register(in git: Git, scriptPath: String) throws {
        _ = try git.run(["config", "merge.union.driver", "true"])
        _ = try git.run(["config", "merge.jsonmerge.name", "deep json merge"])
        _ = try git.run(["config", "merge.jsonmerge.driver", "\(scriptPath) %O %A %B"])
        try ensureAttributes(in: git.repo)
    }

    public static func ensureAttributes(in repo: URL) throws {
        let url = repo.appendingPathComponent(".gitattributes")
        let line = "*.json merge=jsonmerge"
        var contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if contents.contains(line) { return }
        if !contents.isEmpty && !contents.hasSuffix("\n") { contents += "\n" }
        contents += line + "\n"
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
