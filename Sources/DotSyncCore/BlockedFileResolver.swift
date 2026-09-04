import Foundation

public enum BlockedFileAction: Sendable {
    case ignore
    case syncEncrypted
}

public enum BlockedFileResolver {
    public static func apply(
        _ action: BlockedFileAction, files: [String], forbidden: Set<String>,
        git: Git, guards: inout GuardSettings
    ) {
        var untracked: [String] = []
        for file in files {
            switch action {
            case .ignore:
                if forbidden.contains(file), (try? git.untrack(file)) != nil {
                    untracked.append(file)
                }
            case .syncEncrypted:
                if (try? git.untrack(file)) != nil { untracked.append(file) }
                if !guards.forceEncryptPaths.contains(file) {
                    guards.forceEncryptPaths.append(file)
                }
            }
            if !guards.allowlistPaths.contains(file) {
                guards.allowlistPaths.append(file)
            }
        }
        guards.allowlistPaths.sort()
        guards.forceEncryptPaths.sort()
        try? denyTracking(untracked, git: git)
    }

    private static func denyTracking(_ paths: [String], git: Git) throws {
        guard !paths.isEmpty else { return }
        let url = git.repo.appendingPathComponent(".gitignore")
        var contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let existingLines = Set(contents.split(separator: "\n").map(String.init))
        let newLines = paths.map { "/\($0)" }.filter { !existingLines.contains($0) }
        if !newLines.isEmpty {
            if !contents.isEmpty, !contents.hasSuffix("\n") { contents += "\n" }
            contents += newLines.joined(separator: "\n") + "\n"
            try Data(contents.utf8).write(to: url, options: .atomic)
            try git.run(["add", "--", ".gitignore"])
        }

        guard try git.run(["diff", "--cached", "--quiet"]).ok == false else { return }
        try git.run([
            "commit", "--no-verify", "-m",
            "chore(dotsync): stop tracking \(paths.count) blocked file(s)",
        ])
    }
}
