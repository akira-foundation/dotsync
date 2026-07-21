import Foundation

@MainActor
enum PopoverGuard {
    static var onSuspend: (() -> Void)?
    static var onResume: (() -> Void)?

    static func duringModal<T>(_ body: () -> T) -> T {
        onSuspend?()
        defer { onResume?() }
        return body()
    }
}
