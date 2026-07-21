import AppKit
import DotSyncCore
import Foundation
import UniformTypeIdentifiers

struct LogEntry: Identifiable {
    let id = UUID()
    let time: String
    let level: String
    let category: String
    let message: String

    var isError: Bool { level == "Error" || level == "Fault" }
}

enum Diagnostics {
    static func entries(hours: Int) -> [LogEntry] {
        let result = try? Shell.run(
            "/usr/bin/log",
            [
                "show", "--last", "\(hours)h",
                "--predicate", "subsystem == \"\(Log.subsystem)\"",
                "--info", "--debug", "--style", "ndjson",
            ])
        return parse(result?.stdout ?? "")
    }

    static func parse(_ ndjson: String) -> [LogEntry] {
        ndjson.split(separator: "\n").compactMap { line in
            guard let data = line.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let message = object["eventMessage"] as? String, !message.isEmpty
            else { return nil }
            return LogEntry(
                time: clock(object["timestamp"] as? String ?? ""),
                level: object["messageType"] as? String ?? "Default",
                category: object["category"] as? String ?? "general",
                message: message)
        }
    }

    static func clock(_ timestamp: String) -> String {
        guard timestamp.count > 19 else { return "" }
        return String(timestamp.dropFirst(11).prefix(8))
    }

    static func plainText(_ entries: [LogEntry]) -> String {
        entries
            .map { "\($0.time)  \($0.level.prefix(1))  [\($0.category)] \($0.message)" }
            .joined(separator: "\n")
    }

    @MainActor
    static func save(_ text: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save dotsync logs"
        panel.nameFieldStringValue = "dotsync-log-\(stamp()).txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard (try? Data(text.utf8).write(to: url, options: .atomic)) != nil else { return nil }
        return url
    }

    static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

@MainActor
enum LogWindow {
    static var open: (() -> Void)?
}
