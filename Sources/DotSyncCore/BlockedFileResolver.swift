import Foundation

public enum BlockedFileAction: Sendable {
    case ignore
    case syncEncrypted
}

public enum BlockedFileResolver {
    public static func apply(
        _ action: BlockedFileAction, files: [String], forbidden: Set<String>,
        git: Git, guards: inout GuardSettings
    ) {
        for file in files {
            switch action {
            case .ignore:
                if forbidden.contains(file) { _ = try? git.untrack(file) }
            case .syncEncrypted:
                _ = try? git.untrack(file)
                if !guards.forceEncryptPaths.contains(file) {
                    guards.forceEncryptPaths.append(file)
                }
            }
            if !guards.allowlistPaths.contains(file) {
                guards.allowlistPaths.append(file)
            }
        }
        guards.allowlistPaths.sort()
        guards.forceEncryptPaths.sort()
    }
}
