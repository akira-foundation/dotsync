import XCTest

@testable import DotSyncCore

final class SecretScannerTests: XCTestCase {
    func testForbiddenTracked() {
        let tracked = [
            "CLAUDE.md", ".credentials.json", "auth.json",
            "settings.json", "settings.local.json", "skills/x.md",
        ]
        XCTAssertEqual(
            Set(SecretScanner.forbiddenTracked(tracked)),
            Set([".credentials.json", "auth.json", "settings.local.json"])
        )
    }

    func testScanDetectsTokens() {
        XCTAssertEqual(
            SecretScanner.scan(content: "key = sk-abcdefghijklmnopqrstuvwx"), ["api-key"])
        XCTAssertTrue(
            SecretScanner.scan(content: "ghp_0123456789abcdefghijklmnopqrstuvwxyz01").contains(
                "github-token"))
        let realKey = "-----BEGIN RSA PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSj"
        XCTAssertTrue(SecretScanner.scan(content: realKey).contains("private-key"))
    }

    func testPlaceholderPrivateKeyNotFlagged() {
        let doc =
            "\"private_key\": \"-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----\\n\""
        XCTAssertFalse(SecretScanner.scan(content: doc).contains("private-key"))
    }

    func testScanCleanContent() {
        XCTAssertTrue(SecretScanner.scan(content: "just some config\nmodel = opus").isEmpty)
    }

    func testScanRepoIgnoreSkipsFile() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("config.toml", "token = \"ghp_0123456789abcdefghijklmnopqrstuvwxyz01\"\n")
        let git = Git(repo: fx.work)
        _ = try git.run(["add", "-A"])
        _ = try git.run(["commit", "--no-verify", "-m", "add"])

        let report = SecretScanner.scanRepo(fx.work, ignore: ["config.toml"])
        XCTAssertTrue(report.isClean)
    }

    func testScanRepoFindsTrackedSecret() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("config.toml", "token = \"ghp_0123456789abcdefghijklmnopqrstuvwxyz01\"\n")
        let git = Git(repo: fx.work)
        _ = try git.run(["add", "-A"])
        _ = try git.run(["commit", "--no-verify", "-m", "add"])

        let report = SecretScanner.scanRepo(fx.work)
        XCTAssertFalse(report.isClean)
        XCTAssertTrue(
            report.findings.contains(where: {
                $0.file == "config.toml" && $0.rule == "github-token"
            }))
    }

    func testScanRepoFlagsForbiddenFile() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("auth.json", "{}\n")
        let git = Git(repo: fx.work)
        _ = try git.run(["add", "-A"])
        _ = try git.run(["commit", "--no-verify", "-m", "add"])

        let report = SecretScanner.scanRepo(fx.work)
        XCTAssertTrue(report.forbidden.contains("auth.json"))
        XCTAssertFalse(report.isClean)
    }
}
