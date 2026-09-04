import XCTest

@testable import DotSyncCore

final class BlockedFileResolverTests: XCTestCase {
    func testIgnoreUntracksOnlyForbiddenFiles() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile(".credentials.json", "{}\n")
        try fx.writeFile("config.toml", "value = 1\n")
        let git = Git(repo: fx.work)
        _ = try git.run(["add", "-A"])
        _ = try git.run(["commit", "--no-verify", "-m", "add"])

        var guards = GuardSettings()
        BlockedFileResolver.apply(
            .ignore, files: [".credentials.json", "config.toml"],
            forbidden: [".credentials.json"], git: git, guards: &guards)

        let tracked = try git.run(["ls-files"]).stdout
        XCTAssertFalse(tracked.contains(".credentials.json"))
        XCTAssertTrue(tracked.contains("config.toml"))
        XCTAssertEqual(guards.allowlistPaths, [".credentials.json", "config.toml"])
        XCTAssertTrue(guards.forceEncryptPaths.isEmpty)
    }

    func testSyncEncryptedUntracksAndRegistersForceEncrypt() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("config.toml", "value = 1\n")
        let git = Git(repo: fx.work)
        _ = try git.run(["add", "-A"])
        _ = try git.run(["commit", "--no-verify", "-m", "add"])

        var guards = GuardSettings()
        BlockedFileResolver.apply(
            .syncEncrypted, files: ["config.toml"], forbidden: [], git: git, guards: &guards)

        let tracked = try git.run(["ls-files"]).stdout
        XCTAssertFalse(tracked.contains("config.toml"))
        XCTAssertEqual(guards.forceEncryptPaths, ["config.toml"])
        XCTAssertEqual(guards.allowlistPaths, ["config.toml"])
    }

    func testApplyDoesNotDuplicateExistingEntries() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let git = Git(repo: fx.work)

        var guards = GuardSettings(allowlistPaths: ["config.toml"])
        BlockedFileResolver.apply(
            .ignore, files: ["config.toml"], forbidden: [], git: git, guards: &guards)

        XCTAssertEqual(guards.allowlistPaths, ["config.toml"])
    }
}
