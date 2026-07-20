import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public final class FileLock {
    private let fd: Int32
    private var held = false
    private var closed = false

    public init?(path: String) {
        fd = open(path, O_CREAT | O_RDWR, 0o644)
        if fd < 0 { return nil }
    }

    public func tryLock() -> Bool {
        if flock(fd, LOCK_EX | LOCK_NB) == 0 {
            held = true
            return true
        }
        return false
    }

    public func unlock() {
        if closed { return }
        if held {
            flock(fd, LOCK_UN)
            held = false
        }
        close(fd)
        closed = true
    }

    deinit {
        if !closed { close(fd) }
    }
}
