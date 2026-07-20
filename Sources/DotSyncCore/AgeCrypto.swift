import Foundation

public struct AgeKeypair: Equatable, Sendable {
    public let identity: String
    public let recipient: String
}

public enum AgeError: Error, Equatable {
    case notInstalled
    case failed(String)
}

public struct AgeCrypto: Sendable {
    private let runAge: @Sendable ([String]) throws -> ShellResult
    private let runKeygen: @Sendable () throws -> ShellResult

    public init(
        runAge: (@Sendable ([String]) throws -> ShellResult)? = nil,
        runKeygen: (@Sendable () throws -> ShellResult)? = nil
    ) {
        self.runAge =
            runAge ?? { args in
                guard let bin = AgeCrypto.resolveBinary("age") else { throw AgeError.notInstalled }
                return try Shell.run(bin, args)
            }
        self.runKeygen =
            runKeygen ?? {
                guard let bin = AgeCrypto.resolveBinary("age-keygen") else {
                    throw AgeError.notInstalled
                }
                return try Shell.run(bin, [])
            }
    }

    public static func resolveBinary(_ name: String) -> String? {
        let candidates = [
            ProcessInfo.processInfo.environment["DOTSYNC_AGE_DIR"].map { "\($0)/\(name)" },
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static var available: Bool {
        resolveBinary("age") != nil && resolveBinary("age-keygen") != nil
    }

    public func generateKeypair() throws -> AgeKeypair {
        let result = try runKeygen()
        guard result.ok else { throw AgeError.failed(result.stderr) }
        var recipient: String?
        var identity: String?
        for line in result.stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            let text = line.trimmingCharacters(in: .whitespaces)
            if let range = text.range(of: "# public key: ") {
                recipient = String(text[range.upperBound...])
            } else if text.hasPrefix("AGE-SECRET-KEY-") {
                identity = text
            }
        }
        guard let recipient, let identity else { throw AgeError.failed("could not parse keypair") }
        return AgeKeypair(identity: identity, recipient: recipient)
    }

    public func encrypt(input: URL, recipients: [String], output: URL) throws {
        guard !recipients.isEmpty else { throw AgeError.failed("no recipients") }
        var args = ["--output", output.path]
        for recipient in recipients { args += ["--recipient", recipient] }
        args.append(input.path)
        let result = try runAge(args)
        guard result.ok else { throw AgeError.failed(result.stderr) }
    }

    public func decrypt(input: URL, identity: String, output: URL) throws {
        let keyFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-age-\(UUID().uuidString)")
        try Data((identity + "\n").utf8).write(to: keyFile, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: keyFile.path)
        defer { try? FileManager.default.removeItem(at: keyFile) }

        let result = try runAge([
            "--decrypt", "--identity", keyFile.path, "--output", output.path, input.path,
        ])
        guard result.ok else { throw AgeError.failed(result.stderr) }
    }
}
