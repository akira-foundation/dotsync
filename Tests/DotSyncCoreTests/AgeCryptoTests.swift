import XCTest

@testable import DotSyncCore

private func ok(_ stdout: String) -> ShellResult {
    ShellResult(stdout: stdout, stderr: "", exitCode: 0)
}

private final class ArgsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    func record(_ value: [String]) {
        lock.lock()
        stored = value
        lock.unlock()
    }
    var value: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

final class AgeCryptoTests: XCTestCase {
    func testGenerateKeypairParses() throws {
        let sample = """
            # created: 2026-01-01T00:00:00Z
            # public key: age1qxyzpublic
            AGE-SECRET-KEY-1SECRETXYZ
            """
        let age = AgeCrypto(runAge: { _ in ok("") }, runKeygen: { ok(sample) })
        let keypair = try age.generateKeypair()
        XCTAssertEqual(keypair.recipient, "age1qxyzpublic")
        XCTAssertEqual(keypair.identity, "AGE-SECRET-KEY-1SECRETXYZ")
    }

    func testEncryptBuildsMultiRecipientArgs() throws {
        let box = ArgsBox()
        let age = AgeCrypto(
            runAge: { args in
                box.record(args)
                return ok("")
            }, runKeygen: { ok("") })
        try age.encrypt(
            input: URL(fileURLWithPath: "/tmp/a"), recipients: ["age1a", "age1b"],
            output: URL(fileURLWithPath: "/tmp/a.age"))
        XCTAssertEqual(
            box.value,
            ["--output", "/tmp/a.age", "--recipient", "age1a", "--recipient", "age1b", "/tmp/a"])
    }

    func testEncryptNoRecipientsThrows() {
        let age = AgeCrypto(runAge: { _ in ok("") }, runKeygen: { ok("") })
        XCTAssertThrowsError(
            try age.encrypt(
                input: URL(fileURLWithPath: "/tmp/a"), recipients: [],
                output: URL(fileURLWithPath: "/tmp/a.age")))
    }

    func testRealRoundTrip() throws {
        try XCTSkipUnless(AgeCrypto.available, "age not installed")
        let age = AgeCrypto()
        let keypair = try age.generateKeypair()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-age-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let plain = dir.appendingPathComponent("secret.txt")
        let cipher = dir.appendingPathComponent("secret.txt.age")
        let out = dir.appendingPathComponent("out.txt")
        try Data("token-123\n".utf8).write(to: plain)

        try age.encrypt(input: plain, recipients: [keypair.recipient], output: cipher)
        try age.decrypt(input: cipher, identity: keypair.identity, output: out)

        XCTAssertEqual(try String(contentsOf: out, encoding: .utf8), "token-123\n")
    }
}
