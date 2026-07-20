import XCTest

@testable import DotSyncCore

final class RecipientsTests: XCTestCase {
    private func tempRepo() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-rcpt-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testUpsertLoadRemove() throws {
        let repo = tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let recipient = Recipient(
            host: "mac", publicKey: "age1pub", created: "2026-07-21", lastSeen: "2026-07-21")

        try Recipients.upsert(recipient, in: repo)
        XCTAssertEqual(Recipients.load(repo), [recipient])
        XCTAssertEqual(Recipients.publicKeys(repo), ["age1pub"])

        try Recipients.remove(host: "mac", in: repo)
        XCTAssertTrue(Recipients.load(repo).isEmpty)
    }

    func testMultipleRecipients() throws {
        let repo = tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        try Recipients.upsert(
            Recipient(host: "air", publicKey: "age1air", created: "a", lastSeen: "a"), in: repo)
        try Recipients.upsert(
            Recipient(host: "studio", publicKey: "age1studio", created: "b", lastSeen: "b"),
            in: repo)

        XCTAssertEqual(Set(Recipients.publicKeys(repo)), ["age1air", "age1studio"])
    }

    func testUpsertOverwritesSameHost() throws {
        let repo = tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        try Recipients.upsert(
            Recipient(host: "mac", publicKey: "age1old", created: "a", lastSeen: "a"), in: repo)
        try Recipients.upsert(
            Recipient(host: "mac", publicKey: "age1new", created: "a", lastSeen: "b"), in: repo)

        XCTAssertEqual(Recipients.publicKeys(repo), ["age1new"])
    }
}
