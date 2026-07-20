import XCTest
@testable import DotSyncCore

private func okResult(_ stdout: String) -> ShellResult {
    ShellResult(stdout: stdout, stderr: "", exitCode: 0)
}

private func failResult(_ stderr: String) -> ShellResult {
    ShellResult(stdout: "", stderr: stderr, exitCode: 1)
}

private final class ArgsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    func record(_ value: [String]) { lock.lock(); stored = value; lock.unlock() }
    var value: [String] { lock.lock(); defer { lock.unlock() }; return stored }
}

final class GhBridgeTests: XCTestCase {
    func testCurrentUser() throws {
        let gh = GhBridge(host: "github.com") { _ in okResult("kidiatoliny\n") }
        XCTAssertEqual(try gh.currentUser(), "kidiatoliny")
    }

    func testRepoExistsTrue() throws {
        let gh = GhBridge(host: "github.com") { _ in okResult("{}") }
        XCTAssertTrue(try gh.repoExists(owner: "kidiatoliny", name: "dotsync-claude"))
    }

    func testRepoExistsFalseOnNotFound() throws {
        let gh = GhBridge(host: "github.com") { _ in failResult("GraphQL: Could not resolve to a Repository") }
        XCTAssertFalse(try gh.repoExists(owner: "kidiatoliny", name: "nope"))
    }

    func testRepoExistsThrowsOnAuth() {
        let gh = GhBridge(host: "github.com") { _ in failResult("authentication required") }
        XCTAssertThrowsError(try gh.repoExists(owner: "x", name: "y")) { error in
            XCTAssertEqual(error as? GhError, .notAuthenticated)
        }
    }

    func testCreateRepoIsPrivateAndPinsHost() throws {
        let box = ArgsBox()
        let gh = GhBridge(host: "github.com") { args in box.record(args); return okResult("") }
        try gh.createRepo(owner: "kidiatoliny", name: "dotsync-claude", isPrivate: true)
        XCTAssertEqual(box.value,
                       ["repo", "create", "kidiatoliny/dotsync-claude", "--private", "--hostname", "github.com"])
    }

    func testCreateRepoThrowsOnFailure() {
        let gh = GhBridge(host: "github.com") { _ in failResult("name already exists") }
        XCTAssertThrowsError(try gh.createRepo(owner: "x", name: "y", isPrivate: true))
    }

    func testParseAccounts() {
        let status = """
        github.com
          ✓ Logged in to github.com account kidiatoliny (keyring)
          - Active account: true
          - Git operations protocol: https
          ✓ Logged in to github.com account work-bot (keyring)
          - Active account: false
        """
        let accounts = GhBridge.parseAccounts(status)
        XCTAssertEqual(accounts.count, 2)
        XCTAssertEqual(accounts[0], GhAccount(host: "github.com", login: "kidiatoliny", active: true))
        XCTAssertEqual(accounts[1], GhAccount(host: "github.com", login: "work-bot", active: false))
    }
}
