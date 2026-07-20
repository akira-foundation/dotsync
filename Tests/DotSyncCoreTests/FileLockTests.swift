import XCTest

@testable import DotSyncCore

final class FileLockTests: XCTestCase {
    func testSecondLockOnSamePathFails() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("lock-\(UUID().uuidString)").path

        let first = try XCTUnwrap(FileLock(path: path))
        XCTAssertTrue(first.tryLock())

        let second = try XCTUnwrap(FileLock(path: path))
        XCTAssertFalse(second.tryLock(), "second lock must fail while first is held")

        first.unlock()

        let third = try XCTUnwrap(FileLock(path: path))
        XCTAssertTrue(third.tryLock(), "lock available after release")
        third.unlock()
    }

    func testDoubleUnlockIsSafe() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("lock2-\(UUID().uuidString)").path
        let lock = try XCTUnwrap(FileLock(path: path))
        XCTAssertTrue(lock.tryLock())
        lock.unlock()
        lock.unlock()

        let again = try XCTUnwrap(FileLock(path: path))
        XCTAssertTrue(again.tryLock())
        again.unlock()
    }
}
