import XCTest

@testable import DotSyncCore

final class EncryptionCoordinatorTests: XCTestCase {
    private func tempRepo() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-enc-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ repo: URL, _ relative: String, _ body: String = "x\n") throws {
        let url = repo.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(body.utf8).write(to: url)
    }

    func testIsSensitive() {
        XCTAssertTrue(EncryptionCoordinator.isSensitive("auth.json"))
        XCTAssertTrue(EncryptionCoordinator.isSensitive(".credentials.json"))
        XCTAssertTrue(EncryptionCoordinator.isSensitive("settings.local.json"))
        XCTAssertFalse(EncryptionCoordinator.isSensitive("settings.json"))
    }

    func testSensitiveFilesSkipsGitAndConfig() throws {
        let repo = tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        try write(repo, "auth.json")
        try write(repo, "settings.local.json")
        try write(repo, "CLAUDE.md")
        try write(repo, ".git/config")

        XCTAssertEqual(
            EncryptionCoordinator.sensitiveFiles(in: repo), ["auth.json", "settings.local.json"])
    }

    func testAgeFiles() throws {
        let repo = tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        try write(repo, "auth.json.age")
        try write(repo, "CLAUDE.md")
        try write(repo, ".dotsync-age/recipients/mac.json")

        XCTAssertEqual(EncryptionCoordinator.ageFiles(in: repo), ["auth.json.age"])
    }

    func testNeedsEncryptionByModificationTime() throws {
        let repo = tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        try write(repo, "auth.json")
        let input = repo.appendingPathComponent("auth.json")
        let output = repo.appendingPathComponent("auth.json.age")

        XCTAssertTrue(EncryptionCoordinator.needsEncryption(input: input, output: output))

        try write(repo, "auth.json.age", "blob")
        let base = Date(timeIntervalSince1970: 1_000_000)
        try FileManager.default.setAttributes(
            [.modificationDate: base], ofItemAtPath: input.path)
        try FileManager.default.setAttributes(
            [.modificationDate: base.addingTimeInterval(10)], ofItemAtPath: output.path)
        XCTAssertFalse(EncryptionCoordinator.needsEncryption(input: input, output: output))

        try FileManager.default.setAttributes(
            [.modificationDate: base.addingTimeInterval(20)], ofItemAtPath: input.path)
        XCTAssertTrue(EncryptionCoordinator.needsEncryption(input: input, output: output))
    }

    func testEncryptDecryptRoundTrip() throws {
        try XCTSkipUnless(AgeCrypto.available, "age not installed")
        let repo = tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let age = AgeCrypto()
        let keypair = try age.generateKeypair()
        try write(repo, "auth.json", "secret-token\n")

        try EncryptionCoordinator.encryptAll(repo: repo, age: age, recipients: [keypair.recipient])
        try FileManager.default.removeItem(at: repo.appendingPathComponent("auth.json"))
        try EncryptionCoordinator.decryptAll(repo: repo, age: age, identity: keypair.identity)

        let restored = try String(
            contentsOf: repo.appendingPathComponent("auth.json"), encoding: .utf8)
        XCTAssertEqual(restored, "secret-token\n")
    }
}
