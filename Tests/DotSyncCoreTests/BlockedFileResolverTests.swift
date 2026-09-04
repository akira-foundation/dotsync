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

    func testSyncEncryptedPlaintextIsNotRestagedByAddAll() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("config.toml", "value = 1\n")
        let git = Git(repo: fx.work)
        _ = try git.run(["add", "-A"])
        _ = try git.run(["commit", "--no-verify", "-m", "add"])

        var guards = GuardSettings()
        BlockedFileResolver.apply(
            .syncEncrypted, files: ["config.toml"], forbidden: [], git: git, guards: &guards)

        _ = try git.run(["add", "-A"])
        let staged = try git.run(["diff", "--cached", "--name-only"]).stdout
        XCTAssertFalse(staged.contains("config.toml"))
        XCTAssertFalse(try git.run(["ls-files"]).stdout.contains("config.toml"))
    }

    func testIgnoreForbiddenFilePlaintextIsNotRestagedByAddAll() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile(".credentials.json", "{}\n")
        let git = Git(repo: fx.work)
        _ = try git.run(["add", "-A"])
        _ = try git.run(["commit", "--no-verify", "-m", "add"])

        var guards = GuardSettings()
        BlockedFileResolver.apply(
            .ignore, files: [".credentials.json"], forbidden: [".credentials.json"], git: git,
            guards: &guards)

        _ = try git.run(["add", "-A"])
        let staged = try git.run(["diff", "--cached", "--name-only"]).stdout
        XCTAssertFalse(staged.contains(".credentials.json"))
    }

    func testApplyBacksOffWhenRepoIsLocked() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("config.toml", "value = 1\n")
        let git = Git(repo: fx.work)
        _ = try git.run(["add", "-A"])
        _ = try git.run(["commit", "--no-verify", "-m", "add"])

        let lockPath = fx.work.appendingPathComponent(".git/dotsync.lock").path
        let externalLock = FileLock(path: lockPath)
        XCTAssertTrue(externalLock?.tryLock() ?? false)
        defer { externalLock?.unlock() }

        var guards = GuardSettings()
        let applied = BlockedFileResolver.apply(
            .syncEncrypted, files: ["config.toml"], forbidden: [], git: git, guards: &guards)

        XCTAssertFalse(applied)
        XCTAssertTrue(guards.forceEncryptPaths.isEmpty)
        XCTAssertTrue(try git.run(["ls-files"]).stdout.contains("config.toml"))
    }
}
