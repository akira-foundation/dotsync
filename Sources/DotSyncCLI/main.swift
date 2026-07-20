import Foundation
import DotSyncCore

let home = FileManager.default.homeDirectoryForCurrentUser
let configURL = ProcessInfo.processInfo.environment["DOTSYNC_CONFIG"].map(URL.init(fileURLWithPath:))
    ?? home.appendingPathComponent(".dotsync/config.json")
let binDir = ProcessInfo.processInfo.environment["DOTSYNC_BIN"].map(URL.init(fileURLWithPath:))
    ?? home.appendingPathComponent(".dotsync/bin")

func isoNow() -> String {
    let f = ISO8601DateFormatter()
    return f.string(from: Date())
}
func shortHost() -> String {
    ProcessInfo.processInfo.hostName.split(separator: ".").first.map(String.init) ?? "pc"
}

let args = Array(CommandLine.arguments.dropFirst())
exit(CLI.run(args, configURL: configURL, binDir: binDir, now: isoNow, host: shortHost))
