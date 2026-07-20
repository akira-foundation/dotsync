import Foundation

public struct GhAccount: Equatable, Sendable {
    public let host: String
    public let login: String
    public let active: Bool
}

public enum GhError: Error, Equatable {
    case notInstalled
    case notAuthenticated
    case failed(String)
}

public struct GhBridge: Sendable {
    public let host: String
    private let run: @Sendable ([String]) throws -> ShellResult

    public init(host: String = "github.com",
                run: (@Sendable ([String]) throws -> ShellResult)? = nil) {
        self.host = host
        self.run = run ?? { args in try Shell.run(GhBridge.resolveBinary(), args) }
    }

    public static func resolveBinary() -> String {
        let candidates = [
            ProcessInfo.processInfo.environment["DOTSYNC_GH"],
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "gh"
    }

    public func currentUser() throws -> String {
        let result = try run(["api", "user", "--hostname", host, "--jq", ".login"])
        guard result.ok else { throw GhError.notAuthenticated }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func repoExists(owner: String, name: String) throws -> Bool {
        let result = try run(["repo", "view", "\(owner)/\(name)", "--hostname", host])
        if result.ok { return true }
        let err = result.stderr.lowercased()
        if err.contains("could not resolve to a repository") || err.contains("not found") {
            return false
        }
        if err.contains("authentication") || err.contains("not logged") {
            throw GhError.notAuthenticated
        }
        return false
    }

    public func createRepo(owner: String, name: String, isPrivate: Bool) throws {
        let visibility = isPrivate ? "--private" : "--public"
        let result = try run(["repo", "create", "\(owner)/\(name)", visibility, "--hostname", host])
        guard result.ok else { throw GhError.failed(result.stderr) }
    }

    public func accounts() throws -> [GhAccount] {
        let result = try run(["auth", "status"])
        let text = result.stdout + "\n" + result.stderr
        return GhBridge.parseAccounts(text)
    }

    static func parseAccounts(_ text: String) -> [GhAccount] {
        var accounts: [GhAccount] = []
        var host = "github.com"
        var pendingLogin: String?

        func flush(active: Bool) {
            guard let login = pendingLogin else { return }
            accounts.append(GhAccount(host: host, login: login, active: active))
            pendingLogin = nil
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if !line.isEmpty, !line.contains(" "), line.contains(".") {
                flush(active: false)
                host = line
                continue
            }
            if let range = line.range(of: "account ") {
                flush(active: false)
                let after = line[range.upperBound...]
                pendingLogin = after.split(whereSeparator: { $0 == " " || $0 == "(" })
                    .first.map(String.init)
            }
            if line.lowercased().contains("active account: true") {
                flush(active: true)
            }
        }
        flush(active: false)
        return accounts
    }
}
