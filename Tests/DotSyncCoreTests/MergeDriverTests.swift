import XCTest

@testable import DotSyncCore

final class MergeDriverTests: XCTestCase {
    func testInstalledScriptDeepMergesJSON() throws {
        let binDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bin-\(UUID().uuidString)")
        let script = try MergeDrivers.install(binDir: binDir)
        defer { try? FileManager.default.removeItem(at: binDir) }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("merge-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let base = dir.appendingPathComponent("O.json")
        let ours = dir.appendingPathComponent("A.json")
        let theirs = dir.appendingPathComponent("B.json")
        try Data(#"{}"#.utf8).write(to: base)
        try Data(#"{"permissions":{"allow":["a","b"]},"model":"opus"}"#.utf8).write(to: ours)
        try Data(#"{"permissions":{"allow":["b","c"]},"model":"sonnet"}"#.utf8).write(to: theirs)

        let r = try Shell.run("/bin/bash", [script.path, base.path, ours.path, theirs.path])
        XCTAssertEqual(r.exitCode, 0, r.stderr)

        let merged =
            try JSONSerialization.jsonObject(with: Data(contentsOf: ours)) as! [String: Any]
        XCTAssertEqual(merged["model"] as? String, "sonnet")
        let allow = (merged["permissions"] as! [String: Any])["allow"] as! [String]
        XCTAssertEqual(allow.sorted(), ["a", "b", "c"])
    }

    func testRegisterSetsGitConfig() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let g = Git(repo: fx.work)
        try MergeDrivers.register(in: g, scriptPath: "/tmp/json-merge.sh")

        XCTAssertEqual(
            try g.run(["config", "--get", "merge.union.driver"]).stdout
                .trimmingCharacters(in: .whitespacesAndNewlines),
            "true")
        XCTAssertTrue(
            try g.run(["config", "--get", "merge.jsonmerge.driver"]).stdout
                .contains("/tmp/json-merge.sh"))
    }

    func testRealPullDeepMergesJSON() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let g = Git(repo: fx.work)

        let binDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2ebin-\(UUID().uuidString)")
        let script = try MergeDrivers.install(binDir: binDir)
        try MergeDrivers.register(in: g, scriptPath: script.path)

        try fx.writeFile("settings.json", #"{"a":1}"#)
        _ = try g.run(["add", "-A"])
        _ = try g.run(["commit", "--no-verify", "-m", "base json"])
        _ = try g.run(["push", "--no-verify", "origin", "main"])

        let clone = fx.work.deletingLastPathComponent().appendingPathComponent("jclone")
        _ = try Shell.run("/usr/bin/git", ["clone", fx.remote.path, clone.path])
        let cg = Git(repo: clone)
        _ = try cg.run(["config", "user.email", "b@dotsync.local"])
        _ = try cg.run(["config", "user.name", "b"])
        try Data(#"{"a":1,"b":2}"#.utf8).write(to: clone.appendingPathComponent("settings.json"))
        _ = try cg.run(["add", "-A"])
        _ = try cg.run(["commit", "--no-verify", "-m", "add b"])
        _ = try cg.run(["push", "--no-verify", "origin", "main"])

        try Data(#"{"a":1,"c":3}"#.utf8).write(to: fx.work.appendingPathComponent("settings.json"))
        _ = try g.run(["add", "-A"])
        _ = try g.run(["commit", "--no-verify", "-m", "add c"])

        let pull = try g.run(["pull", "--rebase", "--autostash", "origin", "main"])
        XCTAssertTrue(
            pull.ok, "jsonmerge driver should deep-merge instead of conflicting: \(pull.stderr)")

        let data = try Data(contentsOf: fx.work.appendingPathComponent("settings.json"))
        let merged = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(merged["a"])
        XCTAssertNotNil(merged["b"], "remote key b must survive the merge")
        XCTAssertNotNil(merged["c"], "local key c must survive the merge")
    }
}
