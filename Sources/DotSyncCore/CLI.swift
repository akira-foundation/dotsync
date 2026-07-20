import Foundation

public enum CLI {
    public static func run(
        _ args: [String],
        configURL: URL,
        binDir: URL,
        now: @escaping () -> String,
        host: @escaping () -> String
    ) -> Int32 {
        guard let command = args.first else {
            FileHandle.standardError.write(Data("usage: dotsync <sync|status|init> ...\n".utf8))
            return 2
        }
        do {
            let engine = SyncEngine(binDir: binDir, now: now, host: host)
            switch command {
            case "sync":
                let cfg = try Config.load(configURL)
                let targets: [Root]
                if args.contains("--all") {
                    targets = cfg.roots
                } else if args.count >= 2, let r = cfg.root(id: args[1]) {
                    targets = [r]
                } else {
                    FileHandle.standardError.write(Data("sync: unknown root\n".utf8))
                    return 2
                }
                var failed = false
                for r in targets {
                    do {
                        let res = try engine.sync(root: r, config: cfg)
                        print("\(res.rootID): \(res.message)")
                        if !res.pushed && res.message != "locked" { failed = true }
                    } catch {
                        FileHandle.standardError.write(Data("\(r.id): error: \(error)\n".utf8))
                        failed = true
                    }
                }
                return failed ? 1 : 0

            case "status":
                let cfg = try Config.load(configURL)
                let states = cfg.roots.compactMap { try? State.read(for: $0) }
                if args.contains("--json") {
                    let enc = JSONEncoder()
                    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try enc.encode(states)
                    print(String(decoding: data, as: UTF8.self))
                } else {
                    for s in states { print("\(s.rootID)\t\(s.message)\t\(s.timestamp)") }
                }
                return 0

            case "init":
                let cfg = try Config.load(configURL)
                guard args.count >= 2, let r = cfg.root(id: args[1]) else {
                    FileHandle.standardError.write(Data("init: unknown root\n".utf8))
                    return 2
                }
                let script = try MergeDrivers.install(binDir: binDir)
                try MergeDrivers.register(in: Git(repo: r.expandedPath), scriptPath: script.path)
                print("\(r.id): drivers registered")
                return 0

            default:
                FileHandle.standardError.write(Data("unknown command: \(command)\n".utf8))
                return 2
            }
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            return 1
        }
    }
}
