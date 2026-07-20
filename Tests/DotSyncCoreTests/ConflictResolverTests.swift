import XCTest

@testable import DotSyncCore

final class ConflictResolverTests: XCTestCase {
    private func makeBackup(_ fx: GitFixture) throws {
        let git = Git(repo: fx.work)
        try fx.writeFile("note.txt", "remote\n")
        _ = try git.run(["add", "-A"])
        _ = try git.run(["commit", "--no-verify", "-m", "base"])
        _ = try git.run(["branch", "sync-conflict-mac-2026"])
        _ = try git.run(["checkout", "sync-conflict-mac-2026"])
        try fx.writeFile("note.txt", "mine\n")
        _ = try git.run(["add", "-A"])
        _ = try git.run(["commit", "--no-verify", "-m", "local"])
        _ = try git.run(["checkout", "main"])
    }

    func testListsBackups() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try makeBackup(fx)
        XCTAssertEqual(ConflictResolver(repo: fx.work).backups(), ["sync-conflict-mac-2026"])
    }

    func testChangedFiles() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try makeBackup(fx)
        XCTAssertEqual(
            ConflictResolver(repo: fx.work).changedFiles(backup: "sync-conflict-mac-2026"),
            ["note.txt"])
    }

    func testKeepMineBringsContentAndDropsBackup() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try makeBackup(fx)
        let resolver = ConflictResolver(repo: fx.work)
        try resolver.keepMine(backup: "sync-conflict-mac-2026")

        let content = try String(
            contentsOf: fx.work.appendingPathComponent("note.txt"), encoding: .utf8)
        XCTAssertEqual(content, "mine\n")
        XCTAssertTrue(resolver.backups().isEmpty)
    }

    func testDiscardRemovesBackup() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try makeBackup(fx)
        let resolver = ConflictResolver(repo: fx.work)
        try resolver.discard(backup: "sync-conflict-mac-2026")
        XCTAssertTrue(resolver.backups().isEmpty)
    }
}
