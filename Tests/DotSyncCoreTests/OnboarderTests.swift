import XCTest

@testable import DotSyncCore

final class OnboarderTests: XCTestCase {
    func testPlan() {
        XCTAssertEqual(
            Onboarder.plan(isRepo: false, hasRemote: false),
            [.initGit, .createRemote(owner: "", name: ""), .commitAndPush])
        XCTAssertEqual(Onboarder.plan(isRepo: true, hasRemote: true), [.commitAndPush])
        XCTAssertEqual(
            Onboarder.plan(isRepo: true, hasRemote: false),
            [.createRemote(owner: "", name: ""), .commitAndPush])
    }

    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-ob-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func initRepo(_ url: URL) throws {
        _ = try Shell.run("/usr/bin/git", ["init", "-b", "main"], cwd: url)
        _ = try Shell.run("/usr/bin/git", ["config", "user.email", "t@t.dev"], cwd: url)
        _ = try Shell.run("/usr/bin/git", ["config", "user.name", "t"], cwd: url)
    }

    private func settings(account: String?) -> Settings {
        var s = Settings()
        s.github.account = account
        return s
    }

    private func fakeGh(exists: Bool) -> GhBridge {
        GhBridge(host: "github.com") { args in
            if args.first == "repo", args.dropFirst().first == "view" {
                return ShellResult(
                    stdout: exists ? "{}" : "",
                    stderr: exists ? "" : "Could not resolve to a Repository",
                    exitCode: exists ? 0 : 1)
            }
            return ShellResult(stdout: "", stderr: "", exitCode: 0)
        }
    }

    private func root(_ path: String) -> Root {
        Root(
            id: "codex", path: path, remote: nil, branch: "main",
            trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)
    }

    func testHappyPathPushesToRemote() throws {
        let base = tempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let work = base.appendingPathComponent("work")
        let remote = base.appendingPathComponent("remote.git")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        _ = try Shell.run("/usr/bin/git", ["init", "--bare"], cwd: remote)
        try initRepo(work)
        try Data("agents\n".utf8).write(to: work.appendingPathComponent("AGENTS.md"))

        let onboarder = Onboarder(
            settings: settings(account: "me"),
            gh: fakeGh(exists: true),
            confirm: { _ in true },
            remoteURLBuilder: { _, _, _ in remote.path }
        )
        XCTAssertEqual(onboarder.run(root: root(work.path), branch: "main"), .done)

        let verify = try Shell.run(
            "/usr/bin/git", ["-C", remote.path, "rev-parse", "--verify", "main"])
        XCTAssertTrue(verify.ok)
    }

    func testBlockedOnSecretInAllowedFile() throws {
        let base = tempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let work = base.appendingPathComponent("work")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        try initRepo(work)
        try Data("token ghp_0123456789abcdefghijklmnopqrstuvwxyz01\n".utf8)
            .write(to: work.appendingPathComponent("AGENTS.md"))

        let onboarder = Onboarder(
            settings: settings(account: "me"),
            gh: fakeGh(exists: true), confirm: { _ in true })
        guard case .blocked = onboarder.run(root: root(work.path), branch: "main") else {
            return XCTFail("expected blocked")
        }
    }

    func testInitsThenNeedsAccount() throws {
        let base = tempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let work = base.appendingPathComponent("work")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        try Data("agents\n".utf8).write(to: work.appendingPathComponent("AGENTS.md"))

        let onboarder = Onboarder(
            settings: settings(account: nil),
            gh: fakeGh(exists: false), confirm: { _ in true })
        XCTAssertEqual(onboarder.run(root: root(work.path), branch: "main"), .needsAccount)
        XCTAssertTrue(Git(repo: work).isRepo())
    }

    func testCancelledWhenInitDeclined() throws {
        let base = tempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let work = base.appendingPathComponent("work")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        let onboarder = Onboarder(
            settings: settings(account: "me"),
            gh: fakeGh(exists: true), confirm: { _ in false })
        XCTAssertEqual(onboarder.run(root: root(work.path), branch: "main"), .cancelled)
    }
}
