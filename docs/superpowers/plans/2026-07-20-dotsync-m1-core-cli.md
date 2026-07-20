# dotsync M1 (Core + CLI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a headless `dotsync` binary that syncs one or more git-backed config roots (starting with `~/.claude`) with auto-resolving merge drivers, per-root locking, and a deterministic conflict fallback, replacing the current bash Stop-hook.

**Architecture:** A Swift Package Manager package with a pure `DotSyncCore` library (config, shell, git, lock, merge-driver setup, sync flow, state) and a thin `DotSyncCLI` executable that dispatches argv (`sync`, `status`, `init`) to Core. Core orchestrates; the system `git` binary does the plumbing so custom merge drivers keep working.

**Tech Stack:** Swift 6.3, SwiftPM, XCTest, system `git`, `jq` (for the JSON merge driver), flock.

## Global Constraints

- Swift tools version floor: 6.0 (dev toolchain 6.3.3).
- No third-party dependencies. Foundation + Darwin only.
- Git plumbing is always the system `git` at `/usr/bin/git` invoked via `Process`; never libgit2.
- Merge-driver registration is per-clone git config and is NOT committed to any repo.
- Conflict handling must never block and never lose data: residual conflicts save local commits to a `sync-conflict-<host>-<ts>` branch, then reset hard to the remote.
- Per-root advisory lock at `<root>/.git/dotsync.lock` guards every sync; a second concurrent sync of the same root skips.
- State file per root: `<root>/.git/dotsync-state.json`.
- Merge driver script installed to `~/.dotsync/bin/json-merge.sh`; central config at `~/.dotsync/config.json`.

---

## File Structure

```
dotsync/
├─ Package.swift
├─ Sources/
│  ├─ DotSyncCore/
│  │  ├─ Config.swift          Config, Root, Defaults, Trigger; JSON decode; tilde expansion
│  │  ├─ Shell.swift           Process runner -> ShellResult(stdout, stderr, exitCode)
│  │  ├─ Git.swift             Git wrapper over Shell: run, pending, aheadBehind, currentBranch
│  │  ├─ FileLock.swift        flock advisory lock (tryLock/unlock)
│  │  ├─ MergeDrivers.swift    install json-merge.sh, register per-clone git config
│  │  ├─ State.swift           SyncResult model; read/write dotsync-state.json
│  │  └─ SyncEngine.swift      sync(root:) flow returning SyncResult
│  │  └─ Resources/
│  │     └─ json-merge.sh      embedded jq deep-merge driver
│  └─ DotSyncCLI/
│     └─ main.swift            argv dispatch: sync <id|--all> | status [--json] | init <id>
└─ Tests/
   └─ DotSyncCoreTests/
      ├─ Helpers/GitFixture.swift   temp working repo + local bare remote
      ├─ ConfigTests.swift
      ├─ ShellTests.swift
      ├─ GitTests.swift
      ├─ FileLockTests.swift
      ├─ MergeDriverTests.swift
      ├─ StateTests.swift
      └─ SyncEngineTests.swift
```

Each Core file has one responsibility and no UI/CLI knowledge. The CLI is a thin argv shell over Core.

---

### Task 1: Package scaffold + Config model

**Files:**
- Create: `Package.swift`
- Create: `Sources/DotSyncCore/Config.swift`
- Create: `Sources/DotSyncCLI/main.swift` (temporary stub so the executable target builds)
- Test: `Tests/DotSyncCoreTests/ConfigTests.swift`

**Interfaces:**
- Produces: `struct Config { var defaults: Defaults; var roots: [Root]; static func load(_ url: URL) throws -> Config; func root(id: String) -> Root?; func branch(for: Root) -> String; func remote(for: Root) -> String }`, `struct Root { var id: String; var path: String; var remote: String?; var branch: String?; var trigger: Trigger; var auto: Bool?; var intervalSec: Int?; var watch: Bool?; var expandedPath: URL; enum Trigger: String { case hook, scheduler } }`, `struct Defaults { var branch: String; var intervalSec: Int }`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "dotsync",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "DotSyncCore",
            resources: [.copy("Resources/json-merge.sh")]
        ),
        .executableTarget(
            name: "DotSyncCLI",
            dependencies: ["DotSyncCore"]
        ),
        .testTarget(
            name: "DotSyncCoreTests",
            dependencies: ["DotSyncCore"]
        ),
    ]
)
```

- [ ] **Step 2: Create placeholders so the package builds**

Create `Sources/DotSyncCore/Resources/json-merge.sh` with a single line `#!/usr/bin/env bash` (real content lands in Task 5). Create `Sources/DotSyncCLI/main.swift`:

```swift
import DotSyncCore

print("dotsync")
```

- [ ] **Step 3: Write the failing test**

```swift
import XCTest
@testable import DotSyncCore

final class ConfigTests: XCTestCase {
    func testDecodesRootsAndAppliesDefaults() throws {
        let json = """
        {
          "defaults": { "branch": "main", "intervalSec": 300 },
          "roots": [
            { "id": "claude", "path": "~/.claude", "trigger": "hook", "auto": true },
            { "id": "codex", "path": "~/.codex", "trigger": "scheduler",
              "branch": "master", "remote": "upstream", "intervalSec": 600, "watch": true }
          ]
        }
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cfg-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let cfg = try Config.load(url)

        XCTAssertEqual(cfg.roots.count, 2)
        let claude = try XCTUnwrap(cfg.root(id: "claude"))
        XCTAssertEqual(cfg.branch(for: claude), "main")
        XCTAssertEqual(cfg.remote(for: claude), "origin")
        XCTAssertEqual(claude.trigger, .hook)

        let codex = try XCTUnwrap(cfg.root(id: "codex"))
        XCTAssertEqual(cfg.branch(for: codex), "master")
        XCTAssertEqual(cfg.remote(for: codex), "upstream")
        XCTAssertEqual(codex.trigger, .scheduler)
        XCTAssertTrue(codex.expandedPath.path.hasSuffix("/.codex"))
        XCTAssertFalse(codex.expandedPath.path.contains("~"))
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd ~/Akira/macos/dotsync && swift test --filter ConfigTests`
Expected: FAIL - `Config` / `Root` undefined.

- [ ] **Step 5: Implement `Config.swift`**

```swift
import Foundation

public struct Defaults: Codable, Equatable {
    public var branch: String
    public var intervalSec: Int
}

public struct Root: Codable, Equatable {
    public enum Trigger: String, Codable { case hook, scheduler }

    public var id: String
    public var path: String
    public var remote: String?
    public var branch: String?
    public var trigger: Trigger
    public var auto: Bool?
    public var intervalSec: Int?
    public var watch: Bool?

    public var expandedPath: URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
}

public struct Config: Codable, Equatable {
    public var defaults: Defaults
    public var roots: [Root]

    public func root(id: String) -> Root? { roots.first { $0.id == id } }
    public func branch(for r: Root) -> String { r.branch ?? defaults.branch }
    public func remote(for r: Root) -> String { r.remote ?? "origin" }

    public static func load(_ url: URL) throws -> Config {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd ~/Akira/macos/dotsync && swift test --filter ConfigTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd ~/Akira/macos/dotsync
git init -q 2>/dev/null || true
git add Package.swift Sources Tests
git commit -m "feat(core): package scaffold and config model"
```

---

### Task 2: Shell runner

**Files:**
- Create: `Sources/DotSyncCore/Shell.swift`
- Test: `Tests/DotSyncCoreTests/ShellTests.swift`

**Interfaces:**
- Produces: `struct ShellResult { let stdout: String; let stderr: String; let exitCode: Int32; var ok: Bool }`, `enum Shell { static func run(_ executable: String, _ args: [String], cwd: URL?, env: [String:String]?) throws -> ShellResult }`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import DotSyncCore

final class ShellTests: XCTestCase {
    func testCapturesStdoutAndExitCode() throws {
        let r = try Shell.run("/bin/echo", ["hello"], cwd: nil, env: nil)
        XCTAssertEqual(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
        XCTAssertEqual(r.exitCode, 0)
        XCTAssertTrue(r.ok)
    }

    func testNonZeroExitIsReported() throws {
        let r = try Shell.run("/bin/sh", ["-c", "exit 3"], cwd: nil, env: nil)
        XCTAssertEqual(r.exitCode, 3)
        XCTAssertFalse(r.ok)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Akira/macos/dotsync && swift test --filter ShellTests`
Expected: FAIL - `Shell` undefined.

- [ ] **Step 3: Implement `Shell.swift`**

```swift
import Foundation

public struct ShellResult: Equatable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public var ok: Bool { exitCode == 0 }
}

public enum Shell {
    @discardableResult
    public static func run(
        _ executable: String,
        _ args: [String],
        cwd: URL? = nil,
        env: [String: String]? = nil
    ) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        if let cwd { process.currentDirectoryURL = cwd }
        if let env { process.environment = env }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return ShellResult(
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/Akira/macos/dotsync && swift test --filter ShellTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/Akira/macos/dotsync
git add Sources/DotSyncCore/Shell.swift Tests/DotSyncCoreTests/ShellTests.swift
git commit -m "feat(core): process shell runner"
```

---

### Task 3: Git fixture helper + Git wrapper

**Files:**
- Create: `Tests/DotSyncCoreTests/Helpers/GitFixture.swift`
- Create: `Sources/DotSyncCore/Git.swift`
- Test: `Tests/DotSyncCoreTests/GitTests.swift`

**Interfaces:**
- Consumes: `Shell.run`
- Produces: `struct Git { let repo: URL; init(repo: URL); @discardableResult func run(_ args: [String]) throws -> ShellResult; func pending() throws -> [String]; func currentBranch() throws -> String; func aheadBehind(remote: String, branch: String) throws -> (ahead: Int, behind: Int) }`
- Produces (test helper): `struct GitFixture { let work: URL; let remote: URL; static func make() throws -> GitFixture; func writeFile(_ name: String, _ contents: String) throws; func cleanup() }`

- [ ] **Step 1: Write the fixture helper**

```swift
import Foundation
@testable import DotSyncCore

struct GitFixture {
    let work: URL
    let remote: URL

    static func make() throws -> GitFixture {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-\(UUID().uuidString)")
        let work = base.appendingPathComponent("work")
        let remote = base.appendingPathComponent("remote.git")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)

        _ = try Shell.run("/usr/bin/git", ["init", "--bare", "-b", "main"], cwd: remote)

        let g = Git(repo: work)
        _ = try g.run(["init", "-b", "main"])
        _ = try g.run(["config", "user.email", "test@dotsync.local"])
        _ = try g.run(["config", "user.name", "dotsync test"])
        _ = try g.run(["remote", "add", "origin", remote.path])

        let f = GitFixture(work: work, remote: remote)
        try f.writeFile("README.md", "seed\n")
        _ = try g.run(["add", "-A"])
        _ = try g.run(["commit", "-m", "seed"])
        _ = try g.run(["push", "-u", "origin", "main"])
        return f
    }

    func writeFile(_ name: String, _ contents: String) throws {
        let url = work.appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: work.deletingLastPathComponent())
    }
}
```

- [ ] **Step 2: Write the failing test**

```swift
import XCTest
@testable import DotSyncCore

final class GitTests: XCTestCase {
    func testPendingAndAheadBehind() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let g = Git(repo: fx.work)

        XCTAssertEqual(try g.currentBranch(), "main")
        XCTAssertTrue(try g.pending().isEmpty)

        try fx.writeFile("a.txt", "one\n")
        XCTAssertEqual(try g.pending().count, 1)

        _ = try g.run(["add", "-A"])
        _ = try g.run(["commit", "-m", "local commit"])
        let ab = try g.aheadBehind(remote: "origin", branch: "main")
        XCTAssertEqual(ab.ahead, 1)
        XCTAssertEqual(ab.behind, 0)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd ~/Akira/macos/dotsync && swift test --filter GitTests`
Expected: FAIL - `Git` undefined.

- [ ] **Step 4: Implement `Git.swift`**

```swift
import Foundation

public struct Git {
    public let repo: URL
    private let bin = "/usr/bin/git"

    public init(repo: URL) { self.repo = repo }

    @discardableResult
    public func run(_ args: [String]) throws -> ShellResult {
        try Shell.run(bin, args, cwd: repo)
    }

    public func currentBranch() throws -> String {
        try run(["rev-parse", "--abbrev-ref", "HEAD"])
            .stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func pending() throws -> [String] {
        try run(["status", "--porcelain"])
            .stdout
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }

    public func aheadBehind(remote: String, branch: String) throws -> (ahead: Int, behind: Int) {
        let r = try run(["rev-list", "--left-right", "--count", "\(remote)/\(branch)...HEAD"])
        let nums = r.stdout
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .compactMap { Int($0) }
        guard nums.count == 2 else { return (0, 0) }
        return (ahead: nums[1], behind: nums[0])
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd ~/Akira/macos/dotsync && swift test --filter GitTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd ~/Akira/macos/dotsync
git add Sources/DotSyncCore/Git.swift Tests/DotSyncCoreTests/Helpers/GitFixture.swift Tests/DotSyncCoreTests/GitTests.swift
git commit -m "feat(core): git wrapper and test fixture"
```

---

### Task 4: Per-root file lock

**Files:**
- Create: `Sources/DotSyncCore/FileLock.swift`
- Test: `Tests/DotSyncCoreTests/FileLockTests.swift`

**Interfaces:**
- Produces: `final class FileLock { init?(path: String); func tryLock() -> Bool; func unlock() }`

- [ ] **Step 1: Write the failing test**

```swift
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Akira/macos/dotsync && swift test --filter FileLockTests`
Expected: FAIL - `FileLock` undefined.

- [ ] **Step 3: Implement `FileLock.swift`**

```swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public final class FileLock {
    private let fd: Int32
    private var held = false

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
        if held {
            flock(fd, LOCK_UN)
            held = false
        }
        close(fd)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/Akira/macos/dotsync && swift test --filter FileLockTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/Akira/macos/dotsync
git add Sources/DotSyncCore/FileLock.swift Tests/DotSyncCoreTests/FileLockTests.swift
git commit -m "feat(core): advisory per-root file lock"
```

---

### Task 5: Merge drivers (install + register)

**Files:**
- Modify: `Sources/DotSyncCore/Resources/json-merge.sh` (replace stub with real driver)
- Create: `Sources/DotSyncCore/MergeDrivers.swift`
- Test: `Tests/DotSyncCoreTests/MergeDriverTests.swift`

**Interfaces:**
- Consumes: `Git`, `Shell`
- Produces: `enum MergeDrivers { static func scriptURL() -> URL; static func install(binDir: URL) throws -> URL; static func register(in git: Git, scriptPath: String) throws }`

- [ ] **Step 1: Replace `Resources/json-merge.sh` with the real driver**

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE="$1"; OURS="$2"; THEIRS="$3"

if ! command -v jq >/dev/null 2>&1; then
  exit 1
fi

jq -s '
  def deepmerge($a; $b):
    if   ($a | type) == "object" and ($b | type) == "object"
    then reduce ((($a | keys) + ($b | keys)) | unique[]) as $k
           ({}; .[$k] = deepmerge($a[$k]; $b[$k]))
    elif ($a | type) == "array" and ($b | type) == "array"
    then ($a + $b) | unique
    elif $b == null then $a
    else $b
    end;
  deepmerge(.[0]; .[1])
' "$OURS" "$THEIRS" > "$OURS.merged" && mv "$OURS.merged" "$OURS"
```

- [ ] **Step 2: Write the failing test**

```swift
import XCTest
@testable import DotSyncCore

final class MergeDriverTests: XCTestCase {
    func testInstalledScriptDeepMergesJSON() throws {
        let binDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bin-\(UUID().uuidString)")
        let script = try MergeDrivers.install(binDir: binDir)
        defer { try? FileManager.default.removeItem(at: binDir) }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("merge-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let base = dir.appendingPathComponent("O.json")
        let ours = dir.appendingPathComponent("A.json")
        let theirs = dir.appendingPathComponent("B.json")
        try Data(#"{}"#.utf8).write(to: base)
        try Data(#"{"permissions":{"allow":["a","b"]},"model":"opus"}"#.utf8).write(to: ours)
        try Data(#"{"permissions":{"allow":["b","c"]},"model":"sonnet"}"#.utf8).write(to: theirs)

        let r = try Shell.run("/bin/bash", [script.path, base.path, ours.path, theirs.path])
        XCTAssertEqual(r.exitCode, 0, r.stderr)

        let merged = try JSONSerialization.jsonObject(with: Data(contentsOf: ours)) as! [String: Any]
        XCTAssertEqual(merged["model"] as? String, "sonnet")
        let allow = (merged["permissions"] as! [String: Any])["allow"] as! [String]
        XCTAssertEqual(allow.sorted(), ["a", "b", "c"])
    }

    func testRegisterSetsGitConfig() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let g = Git(repo: fx.work)
        try MergeDrivers.register(in: g, scriptPath: "/tmp/json-merge.sh")

        XCTAssertEqual(
            try g.run(["config", "--get", "merge.union.driver"]).stdout
                .trimmingCharacters(in: .whitespacesAndNewlines),
            "true")
        XCTAssertTrue(
            try g.run(["config", "--get", "merge.jsonmerge.driver"]).stdout
                .contains("/tmp/json-merge.sh"))
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd ~/Akira/macos/dotsync && swift test --filter MergeDriverTests`
Expected: FAIL - `MergeDrivers` undefined.

- [ ] **Step 4: Implement `MergeDrivers.swift`**

```swift
import Foundation

public enum MergeDrivers {
    public static func scriptURL() -> URL {
        Bundle.module.url(forResource: "json-merge", withExtension: "sh")!
    }

    @discardableResult
    public static func install(binDir: URL) throws -> URL {
        try FileManager.default.createDirectory(
            at: binDir, withIntermediateDirectories: true)
        let dest = binDir.appendingPathComponent("json-merge.sh")
        let data = try Data(contentsOf: scriptURL())
        try data.write(to: dest)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: dest.path)
        return dest
    }

    public static func register(in git: Git, scriptPath: String) throws {
        _ = try git.run(["config", "merge.union.driver", "true"])
        _ = try git.run(["config", "merge.jsonmerge.name", "deep json merge"])
        _ = try git.run(["config", "merge.jsonmerge.driver", "\(scriptPath) %O %A %B"])
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd ~/Akira/macos/dotsync && swift test --filter MergeDriverTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd ~/Akira/macos/dotsync
git add Sources/DotSyncCore/Resources/json-merge.sh Sources/DotSyncCore/MergeDrivers.swift Tests/DotSyncCoreTests/MergeDriverTests.swift
git commit -m "feat(core): install and register merge drivers"
```

---

### Task 6: State model + persistence

**Files:**
- Create: `Sources/DotSyncCore/State.swift`
- Test: `Tests/DotSyncCoreTests/StateTests.swift`

**Interfaces:**
- Produces: `struct SyncResult: Codable, Equatable { var rootID: String; var timestamp: String; var pushed: Bool; var conflict: Bool; var backupBranch: String?; var pendingBefore: Int; var message: String }`, `enum State { static func path(for root: Root) -> URL; static func write(_ result: SyncResult, for root: Root) throws; static func read(for root: Root) throws -> SyncResult? }`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import DotSyncCore

final class StateTests: XCTestCase {
    func testWriteThenReadRoundTrips() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let root = Root(id: "t", path: fx.work.path, remote: nil, branch: nil,
                        trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)

        let result = SyncResult(rootID: "t", timestamp: "2026-07-20T00:00:00Z",
                                pushed: true, conflict: false, backupBranch: nil,
                                pendingBefore: 2, message: "ok")
        try State.write(result, for: root)

        let back = try XCTUnwrap(State.read(for: root))
        XCTAssertEqual(back, result)
        XCTAssertTrue(State.path(for: root).path.hasSuffix("/.git/dotsync-state.json"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Akira/macos/dotsync && swift test --filter StateTests`
Expected: FAIL - `SyncResult` / `State` undefined.

- [ ] **Step 3: Implement `State.swift`**

```swift
import Foundation

public struct SyncResult: Codable, Equatable {
    public var rootID: String
    public var timestamp: String
    public var pushed: Bool
    public var conflict: Bool
    public var backupBranch: String?
    public var pendingBefore: Int
    public var message: String

    public init(rootID: String, timestamp: String, pushed: Bool, conflict: Bool,
                backupBranch: String?, pendingBefore: Int, message: String) {
        self.rootID = rootID
        self.timestamp = timestamp
        self.pushed = pushed
        self.conflict = conflict
        self.backupBranch = backupBranch
        self.pendingBefore = pendingBefore
        self.message = message
    }
}

public enum State {
    public static func path(for root: Root) -> URL {
        root.expandedPath.appendingPathComponent(".git/dotsync-state.json")
    }

    public static func write(_ result: SyncResult, for root: Root) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(result).write(to: path(for: root))
    }

    public static func read(for root: Root) throws -> SyncResult? {
        let url = path(for: root)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(SyncResult.self, from: Data(contentsOf: url))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/Akira/macos/dotsync && swift test --filter StateTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/Akira/macos/dotsync
git add Sources/DotSyncCore/State.swift Tests/DotSyncCoreTests/StateTests.swift
git commit -m "feat(core): sync result state persistence"
```

---

### Task 7: Sync engine - happy path

**Files:**
- Create: `Sources/DotSyncCore/SyncEngine.swift`
- Test: `Tests/DotSyncCoreTests/SyncEngineTests.swift`

**Interfaces:**
- Consumes: `Config`, `Root`, `Git`, `FileLock`, `MergeDrivers`, `State`, `SyncResult`
- Produces: `struct SyncEngine { var binDir: URL; var now: () -> String; var host: () -> String; init(binDir: URL, now: @escaping () -> String, host: @escaping () -> String); func sync(root: Root, config: Config) throws -> SyncResult }`

The engine timestamp and host are injected so tests are deterministic.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import DotSyncCore

final class SyncEngineTests: XCTestCase {
    private func makeEngine() -> SyncEngine {
        let binDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("enginebin-\(UUID().uuidString)")
        return SyncEngine(binDir: binDir, now: { "2026-07-20T00:00:00Z" }, host: { "testpc" })
    }

    private func root(_ fx: GitFixture) -> Root {
        Root(id: "t", path: fx.work.path, remote: "origin", branch: "main",
             trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)
    }

    private func config() -> Config {
        Config(defaults: Defaults(branch: "main", intervalSec: 300), roots: [])
    }

    func testLocalChangeCommitsAndPushes() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("note.txt", "hello\n")

        let result = try makeEngine().sync(root: root(fx), config: config())

        XCTAssertTrue(result.pushed)
        XCTAssertFalse(result.conflict)
        XCTAssertEqual(result.pendingBefore, 1)

        let g = Git(repo: fx.work)
        let ab = try g.aheadBehind(remote: "origin", branch: "main")
        XCTAssertEqual(ab.ahead, 0, "local must be pushed")
        XCTAssertEqual(ab.behind, 0)
    }

    func testRemoteChangeIsPulled() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }

        // Simulate another machine pushing to the remote via a second clone.
        let clone = fx.work.deletingLastPathComponent().appendingPathComponent("clone")
        _ = try Shell.run("/usr/bin/git", ["clone", fx.remote.path, clone.path])
        let cg = Git(repo: clone)
        _ = try cg.run(["config", "user.email", "b@dotsync.local"])
        _ = try cg.run(["config", "user.name", "b"])
        try Data("remote\n".utf8).write(to: clone.appendingPathComponent("remote.txt"))
        _ = try cg.run(["add", "-A"])
        _ = try cg.run(["commit", "-m", "remote change"])
        _ = try cg.run(["push", "origin", "main"])

        let result = try makeEngine().sync(root: root(fx), config: config())
        XCTAssertFalse(result.conflict)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: fx.work.appendingPathComponent("remote.txt").path))
    }

    func testConcurrentSyncSkipsViaLock() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let lockPath = fx.work.appendingPathComponent(".git/dotsync.lock").path
        let held = try XCTUnwrap(FileLock(path: lockPath))
        XCTAssertTrue(held.tryLock())
        defer { held.unlock() }

        try fx.writeFile("note.txt", "hello\n")
        let result = try makeEngine().sync(root: root(fx), config: config())
        XCTAssertEqual(result.message, "locked")
        XCTAssertFalse(result.pushed)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Akira/macos/dotsync && swift test --filter SyncEngineTests`
Expected: FAIL - `SyncEngine` undefined.

- [ ] **Step 3: Implement `SyncEngine.swift`**

```swift
import Foundation

public struct SyncEngine {
    public var binDir: URL
    public var now: () -> String
    public var host: () -> String

    public init(binDir: URL, now: @escaping () -> String, host: @escaping () -> String) {
        self.binDir = binDir
        self.now = now
        self.host = host
    }

    public func sync(root: Root, config: Config) throws -> SyncResult {
        let ts = now()
        let git = Git(repo: root.expandedPath)
        let remote = config.remote(for: root)
        let branch = config.branch(for: root)

        let lockPath = root.expandedPath.appendingPathComponent(".git/dotsync.lock").path
        guard let lock = FileLock(path: lockPath), lock.tryLock() else {
            return SyncResult(rootID: root.id, timestamp: ts, pushed: false, conflict: false,
                              backupBranch: nil, pendingBefore: 0, message: "locked")
        }
        defer { lock.unlock() }

        let script = try MergeDrivers.install(binDir: binDir)
        try MergeDrivers.register(in: git, scriptPath: script.path)

        let pending = try git.pending().count
        _ = try git.run(["add", "-A"])
        let staged = try git.run(["diff", "--cached", "--quiet"])
        if !staged.ok {
            _ = try git.run(["commit", "-m", "chore(auto-sync): \(pending) file(s) [\(ts)] \(host())"])
        }

        let pull = try git.run(["pull", "--rebase", "--autostash", remote, branch])
        var conflict = false
        var backup: String? = nil
        if !pull.ok {
            conflict = true
            let name = "sync-conflict-\(host())-\(ts)"
            backup = name
            _ = try git.run(["branch", "-f", name, "HEAD"])
            _ = try git.run(["rebase", "--abort"])
            _ = try git.run(["fetch", remote, branch])
            _ = try git.run(["reset", "--hard", "\(remote)/\(branch)"])
        }

        let push = try git.run(["push", remote, branch])
        let result = SyncResult(
            rootID: root.id, timestamp: ts, pushed: push.ok, conflict: conflict,
            backupBranch: backup, pendingBefore: pending,
            message: conflict ? "conflict-resolved" : (push.ok ? "pushed" : "push-failed"))
        try State.write(result, for: root)
        return result
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/Akira/macos/dotsync && swift test --filter SyncEngineTests`
Expected: PASS (all three cases).

- [ ] **Step 5: Commit**

```bash
cd ~/Akira/macos/dotsync
git add Sources/DotSyncCore/SyncEngine.swift Tests/DotSyncCoreTests/SyncEngineTests.swift
git commit -m "feat(core): sync engine with lock, drivers, push"
```

---

### Task 8: Sync engine - conflict fallback

**Files:**
- Modify: `Tests/DotSyncCoreTests/SyncEngineTests.swift` (add conflict case)

**Interfaces:**
- Consumes: `SyncEngine.sync` (already produced in Task 7)

This task proves the deterministic fallback: a non-driver file changed on both sides produces a rebase conflict; the engine must save a backup branch, reset to remote, and still report a resolved (non-blocking) result.

- [ ] **Step 1: Add the failing test**

```swift
extension SyncEngineTests {
    func testResidualConflictSavesBackupAndTakesRemote() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }

        // Remote edits README via a second clone.
        let clone = fx.work.deletingLastPathComponent().appendingPathComponent("clone2")
        _ = try Shell.run("/usr/bin/git", ["clone", fx.remote.path, clone.path])
        let cg = Git(repo: clone)
        _ = try cg.run(["config", "user.email", "b@dotsync.local"])
        _ = try cg.run(["config", "user.name", "b"])
        try Data("remote-line\n".utf8).write(to: clone.appendingPathComponent("README.md"))
        _ = try cg.run(["add", "-A"]); _ = try cg.run(["commit", "-m", "remote README"])
        _ = try cg.run(["push", "origin", "main"])

        // Local edits the same README differently (no merge driver for .md).
        try fx.writeFile("README.md", "local-line\n")

        let engine = SyncEngine(
            binDir: FileManager.default.temporaryDirectory
                .appendingPathComponent("cbin-\(UUID().uuidString)"),
            now: { "2026-07-20T11-22-33Z" }, host: { "testpc" })
        let root = Root(id: "t", path: fx.work.path, remote: "origin", branch: "main",
                        trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)
        let cfg = Config(defaults: Defaults(branch: "main", intervalSec: 300), roots: [])

        let result = try engine.sync(root: root, config: cfg)

        XCTAssertTrue(result.conflict)
        XCTAssertEqual(result.backupBranch, "sync-conflict-testpc-2026-07-20T11-22-33Z")

        let g = Git(repo: fx.work)
        let readme = try String(contentsOf: fx.work.appendingPathComponent("README.md"), encoding: .utf8)
        XCTAssertEqual(readme, "remote-line\n", "remote wins after fallback")

        let branches = try g.run(["branch", "--list", "sync-conflict-*"]).stdout
        XCTAssertTrue(branches.contains("sync-conflict-testpc-2026-07-20T11-22-33Z"),
                      "local work preserved on backup branch")
    }
}
```

- [ ] **Step 2: Run test to verify it fails or passes**

Run: `cd ~/Akira/macos/dotsync && swift test --filter SyncEngineTests/testResidualConflictSavesBackupAndTakesRemote`
Expected: If Task 7's engine already handles the fallback, this PASSES immediately - that is acceptable (it is the regression guard). If it FAILS, fix `SyncEngine.sync` so the conflict branch matches the code in Task 7 Step 3.

- [ ] **Step 3: Commit**

```bash
cd ~/Akira/macos/dotsync
git add Tests/DotSyncCoreTests/SyncEngineTests.swift
git commit -m "test(core): guard deterministic conflict fallback"
```

---

### Task 9: CLI dispatch

**Files:**
- Modify: `Sources/DotSyncCLI/main.swift` (replace the Task 1 stub)
- Test: `Tests/DotSyncCoreTests/CLITests.swift`

**Interfaces:**
- Consumes: `Config`, `SyncEngine`, `State`, `MergeDrivers`
- Produces: CLI commands `dotsync sync <id|--all>`, `dotsync status [--json]`, `dotsync init <id>`. Config resolved from `DOTSYNC_CONFIG` env var if set, else `~/.dotsync/config.json`. Bin dir from `DOTSYNC_BIN` env var if set, else `~/.dotsync/bin`.

Because `main.swift` is not importable, the CLI logic lives in a testable `enum CLI` inside Core.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import DotSyncCore

final class CLITests: XCTestCase {
    func testSyncAllReturnsZeroAndWritesState() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("x.txt", "hi\n")

        let cfgURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cli-\(UUID().uuidString).json")
        let json = """
        { "defaults": { "branch": "main", "intervalSec": 300 },
          "roots": [ { "id": "t", "path": "\(fx.work.path)", "trigger": "scheduler", "auto": true } ] }
        """
        try Data(json.utf8).write(to: cfgURL)
        defer { try? FileManager.default.removeItem(at: cfgURL) }

        let binDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clibin-\(UUID().uuidString)")

        let code = CLI.run(
            ["sync", "--all"], configURL: cfgURL, binDir: binDir,
            now: { "2026-07-20T00:00:00Z" }, host: { "testpc" })
        XCTAssertEqual(code, 0)

        let root = Root(id: "t", path: fx.work.path, remote: nil, branch: nil,
                        trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)
        let state = try XCTUnwrap(State.read(for: root))
        XCTAssertTrue(state.pushed)
    }

    func testUnknownCommandReturnsNonZero() {
        let code = CLI.run(
            ["frobnicate"], configURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nope.json"),
            binDir: FileManager.default.temporaryDirectory,
            now: { "" }, host: { "" })
        XCTAssertNotEqual(code, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Akira/macos/dotsync && swift test --filter CLITests`
Expected: FAIL - `CLI` undefined.

- [ ] **Step 3: Implement `CLI` in Core**

Create `Sources/DotSyncCore/CLI.swift`:

```swift
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
                    let res = try engine.sync(root: r, config: cfg)
                    print("\(res.rootID): \(res.message)")
                    if !res.pushed && res.message != "locked" { failed = true }
                }
                return failed ? 1 : 0

            case "status":
                let cfg = try Config.load(configURL)
                let states = cfg.roots.compactMap { try? State.read(for: $0) }.compactMap { $0 }
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
```

- [ ] **Step 4: Wire `main.swift` to `CLI.run` with real defaults**

```swift
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd ~/Akira/macos/dotsync && swift test --filter CLITests`
Expected: PASS.

- [ ] **Step 6: Build the release binary and smoke-test**

Run:
```bash
cd ~/Akira/macos/dotsync && swift build -c release
DOTSYNC_CONFIG=/dev/null .build/release/DotSyncCLI frobnicate; echo "exit=$?"
```
Expected: prints `unknown command: frobnicate`, `exit=2`.

- [ ] **Step 7: Commit**

```bash
cd ~/Akira/macos/dotsync
git add Sources/DotSyncCore/CLI.swift Sources/DotSyncCLI/main.swift Tests/DotSyncCoreTests/CLITests.swift
git commit -m "feat(cli): sync, status, init dispatch"
```

---

### Task 10: Migrate the Claude Stop-hook to `dotsync`

**Files:**
- Create: `~/.dotsync/config.json`
- Create: symlink `~/.dotsync/bin/dotsync` -> release binary
- Modify: `~/.claude/hooks/claude-sync.sh`

**Interfaces:**
- Consumes: `dotsync sync claude` CLI (Task 9)

This task swaps the existing bash sync for the new binary on the real `~/.claude` root. It touches the live synced repo, so it verifies before and does not delete the old script content until the new path is proven.

- [ ] **Step 1: Install the binary and central config**

Run:
```bash
mkdir -p ~/.dotsync/bin
ln -sf ~/Akira/macos/dotsync/.build/release/DotSyncCLI ~/.dotsync/bin/dotsync
cat > ~/.dotsync/config.json <<'JSON'
{
  "defaults": { "branch": "main", "intervalSec": 300 },
  "roots": [
    { "id": "claude", "path": "~/.claude", "remote": "origin", "branch": "main", "trigger": "hook", "auto": true }
  ]
}
JSON
```

- [ ] **Step 2: Register drivers on the live root and dry-run status**

Run:
```bash
~/.dotsync/bin/dotsync init claude
~/.dotsync/bin/dotsync status
```
Expected: `claude: drivers registered`, then a status line (or empty if no prior state).

- [ ] **Step 3: Replace the hook body**

Replace the entire contents of `~/.claude/hooks/claude-sync.sh` with:

```bash
#!/usr/bin/env bash
set -uo pipefail
exec "$HOME/.dotsync/bin/dotsync" sync claude >> "$HOME/.claude/.sync.log" 2>&1
```

- [ ] **Step 4: Verify a real sync round-trips**

Run:
```bash
date >> ~/.claude/.sync-probe && ~/.claude/hooks/claude-sync.sh; echo "exit=$?"
tail -3 ~/.claude/.sync.log
cd ~/.claude && git log -1 --oneline && git rev-list --left-right --count origin/main...HEAD
```
Expected: `exit=0`; log shows `claude: pushed`; ahead/behind both `0`.

- [ ] **Step 5: Commit the project (hook lives in the synced repo, not this one)**

```bash
cd ~/Akira/macos/dotsync
git add -A
git commit -m "docs(m1): record hook migration steps"
```
Note: `~/.claude/hooks/claude-sync.sh` is committed by the `~/.claude` repo's own auto-sync, not by this project.

---

## Self-Review

**Spec coverage:**
- Swift-orchestrates/git-executes decision - Tasks 2, 3 (Shell + Git via Process). Covered.
- Config `~/.dotsync/config.json` central, hook-readable - Tasks 1, 9, 10. Covered.
- Per-root lock preventing hook/app race - Tasks 4, 7 (`testConcurrentSyncSkipsViaLock`). Covered.
- Sync flow add/commit → pull --rebase → push - Task 7. Covered.
- Merge drivers auto-resolve (JSON deep-merge, memory union) - Task 5. Covered.
- Deterministic conflict fallback + backup branch, no loss - Tasks 7, 8. Covered.
- State file `<root>/.git/dotsync-state.json` - Task 6. Covered.
- CLI `sync/status/init` - Task 9. Covered.
- Claude Stop-hook reduced to `dotsync sync claude` - Task 10. Covered.
- Menu-bar UI, scheduler/daemon, auto-discover, rules editor - deferred to M2-M4 by design (out of M1 scope).

**Placeholder scan:** No TBD/TODO; every code step contains complete code; every test step contains real assertions.

**Type consistency:** `SyncResult` fields identical across Tasks 6, 7, 8, 9. `SyncEngine.init(binDir:now:host:)` signature identical in Tasks 7, 8, 9. `MergeDrivers.install(binDir:)`/`register(in:scriptPath:)` identical in Tasks 5, 7, 9. `Git.aheadBehind(remote:branch:)` identical in Tasks 3, 7. Consistent.

## Out of scope (separate plans)

- **M2** - MenuBarExtra viewer over `DotSyncCore`.
- **M3** - multi-root scheduler + LaunchAgent daemon + auto-discover + Codex onboarding.
- **M4** - rules editor (with preview) and conflicts view.
