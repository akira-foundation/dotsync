import XCTest

@testable import DotSyncCore

final class SettingsTests: XCTestCase {
    func testDefaults() {
        let settings = Settings()
        XCTAssertEqual(settings.github.host, "github.com")
        XCTAssertEqual(settings.github.visibility, "private")
        XCTAssertFalse(settings.github.autoCreateRemote)
        XCTAssertTrue(settings.discovery.enabled)
        XCTAssertEqual(settings.discovery.paths, ["~/.claude", "~/.codex"])
        XCTAssertTrue(settings.guards.requirePrivate)
        XCTAssertTrue(settings.guards.blockOnTrackedSecrets)
    }

    func testLoadMissingReturnsDefaults() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-\(UUID().uuidString)/settings.json")
        XCTAssertEqual(try Settings.load(url), Settings())
    }

    func testSaveRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-\(UUID().uuidString)/settings.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var settings = Settings()
        settings.github.account = "kidiatoliny"
        settings.discovery.paths = ["~/.claude"]
        try settings.save(to: url)

        XCTAssertEqual(try Settings.load(url), settings)
    }

    func testRepoNameTemplate() {
        let settings = Settings()
        XCTAssertEqual(settings.repoName(for: "claude"), "dotsync-claude")
    }

    func testDiscoveryIgnoredDefaultsEmptyAndTolerant() throws {
        XCTAssertTrue(Settings().discovery.ignored.isEmpty)

        let json = """
            { "discovery": { "enabled": true, "autoAdd": true, "paths": ["~/.claude"] } }
            """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(try Settings.load(url).discovery.ignored.isEmpty)
    }

    func testEncryptionDefaults() {
        let settings = Settings()
        XCTAssertFalse(settings.encryption.enabled)
        XCTAssertNil(settings.encryption.recipient)
    }

    func testAutoSyncDefaults() {
        let settings = Settings()
        XCTAssertTrue(settings.autosync.enabled)
        XCTAssertEqual(settings.autosync.intervalSec, 300)
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testDecodesAutosyncWithoutWatch() throws {
        let json = """
            { "autosync": { "enabled": true, "intervalSec": 60 } }
            """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let settings = try Settings.load(url)
        XCTAssertEqual(settings.autosync.intervalSec, 60)
        XCTAssertFalse(settings.autosync.watch)
    }

    func testDecodesLegacyFileWithoutAutosync() throws {
        let json = """
            { "github": { "host": "github.com", "visibility": "private",
              "repoNameTemplate": "dotsync-{id}", "autoCreateRemote": false } }
            """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let settings = try Settings.load(url)
        XCTAssertTrue(settings.autosync.enabled)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertEqual(settings.discovery.paths, ["~/.claude", "~/.codex"])
    }
}
