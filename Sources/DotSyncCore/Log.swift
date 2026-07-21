import Foundation
import os

public enum Log {
    public static let subsystem = "io.akira.dotsync"

    public static let sync = Logger(subsystem: subsystem, category: "sync")
    public static let onboard = Logger(subsystem: subsystem, category: "onboard")
    public static let gh = Logger(subsystem: subsystem, category: "gh")
    public static let crypto = Logger(subsystem: subsystem, category: "crypto")
    public static let watch = Logger(subsystem: subsystem, category: "watch")

    static let stderrLimit = 400

    public static func failure(_ label: String, _ result: ShellResult) -> String {
        summarize(label, exitCode: result.exitCode, stderr: result.stderr)
    }

    public static func summarize(_ label: String, exitCode: Int32, stderr: String) -> String {
        let detail = clip(redact(stderr.trimmingCharacters(in: .whitespacesAndNewlines)))
        guard !detail.isEmpty else { return "\(label) failed (exit \(exitCode))" }
        return "\(label) failed (exit \(exitCode)): \(detail)"
    }

    static func redact(_ text: String) -> String {
        let pattern = "//[^/@\\s]+@"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text, range: range, withTemplate: "//<redacted>@")
    }

    static func clip(_ text: String) -> String {
        guard text.count > stderrLimit else { return text }
        return String(text.prefix(stderrLimit)) + "\u{2026}"
    }
}
