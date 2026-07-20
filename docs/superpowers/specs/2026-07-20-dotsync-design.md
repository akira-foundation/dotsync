# dotsync - Design

Date: 2026-07-20
Status: Approved (brainstorming)

## Problem

Dotfile/config directories for AI tools (`~/.claude`, `~/.codex`, ...) are synced across
multiple machines via GitHub. The current `~/.claude` setup pushes without pulling and
commits per-machine state, causing constant merge conflicts. A first fix (merge drivers +
`pull --rebase` + allowlist ignore) is already live for `~/.claude`. This project generalizes
that engine and puts a face on it: a macOS menu-bar helper that shows what is syncing, what is
pending, surfaces conflicts, lets the user manage ignore rules, and manages multiple tool roots
(Claude, Codex, and others).

## Goals

- One place to see sync state across every managed root: last sync, ahead/behind, pending files,
  conflict backups.
- Manual sync-now and per-root auto toggle.
- Edit `.gitignore` / `.gitattributes` per root through the UI, safely (preview before save).
- Manage multiple roots from a central config; auto-discover candidates.
- Conflicts never block and never lose data (deterministic fallback + backup branch).

## Non-Goals (v1)

- Cross-machine live presence or real-time collaboration.
- Syncing per-machine state (session transcripts, logs, caches). Those stay ignored.
- Signed/notarized distribution or App Store packaging.
- Windows/Linux tray equivalents.

## Key Decision: Swift orchestrates, `git` executes

The sync brain is Swift-native, but `DotSyncCore` shells out to the system `git` binary via
`Process` rather than embedding libgit2. Reason: conflict auto-resolution depends on git's merge
machinery honoring our custom merge drivers (`jsonmerge` deep-merge, `union`) declared in
`.gitattributes`. libgit2 does not run custom driver scripts. Swift owns orchestration, locking,
config, state, and UI; git does the plumbing.

## Architecture

Single Swift package producing one universal binary. No args launches the menu-bar app; with
args it behaves as a CLI (argv dispatch). The same binary is what the Claude Stop-hook calls.

```
dotsync (Swift package)
├─ DotSyncCore   pure library: config model, git operations, merge-driver setup,
│                per-root lock, sync flow, state emission. Unit-testable, no UI.
├─ DotSyncCLI    argv dispatch over Core: sync | status | init | add | discover | daemon
└─ DotSyncApp    SwiftUI MenuBarExtra over Core
```

### Module boundaries

- `DotSyncCore` - depends only on Foundation + system `git`. Public API: `Config`, `Root`,
  `SyncResult`, `sync(root:)`, `status(root:)`, `register(root:)`, `discover()`. No knowledge of
  SwiftUI or CLI.
- `DotSyncCLI` - depends on Core. Parses argv, maps to Core calls, prints human or `--json`
  output, sets exit codes. No git logic of its own.
- `DotSyncApp` - depends on Core. MenuBarExtra UI, scheduler timers, file watchers,
  notifications. Never calls `git` directly; always through Core.

## Config: `~/.dotsync/config.json`

Single source of truth, read by both the Swift binary and any bash hook.

```json
{
  "defaults": { "branch": "main", "intervalSec": 300 },
  "roots": [
    { "id": "claude", "path": "~/.claude", "trigger": "hook",      "auto": true },
    { "id": "codex",  "path": "~/.codex",  "trigger": "scheduler", "auto": true,
      "intervalSec": 600, "watch": true }
  ]
}
```

- `trigger: "hook"` - an external hook fires sync for this root; the app only observes state and
  offers manual sync. The app scheduler does NOT auto-fire it.
- `trigger: "scheduler"` - the app's timer (and optional file `watch`) fires sync for this root.
- Per-root fields override `defaults`. `remote` defaults to `origin`.

This field is the hybrid switch, per root: Claude keeps its Stop-hook trigger; Codex and others
are driven by the app scheduler.

## Sync flow - `Core.sync(root)`

1. Acquire a per-root advisory lock at `<root>/.git/dotsync.lock` (flock). If already held, skip
   this run. This is what prevents the Claude Stop-hook and the app scheduler from racing.
2. `git add -A`; if anything is staged, commit with an auto-sync message tagged with hostname and
   UTC timestamp.
3. `git pull --rebase --autostash <remote> <branch>`. Merge drivers auto-resolve JSON config
   (deep-merge) and memory files (union) with no loss.
4. On clean rebase: `git push`. On residual conflict (a file no driver covers):
   - Save local commits on a backup branch `sync-conflict-<host>-<ts>`.
   - `git rebase --abort`, `git fetch`, `git reset --hard <remote>/<branch>` (remote wins, local
     recoverable from the backup branch). Never blocks, never silently loses.
5. Write `<root>/.git/dotsync-state.json`: last result, timestamp, pushed/failed, pending count,
   ahead/behind, conflict flag, backup branch name if any. The UI reads this.

### Merge-driver setup

Merge-driver registration is per-clone git config (does not travel in the repo, by git's design).
On the first sync of a root (or via `dotsync init <root>`), Core:

- Registers `merge.union.driver true` and `merge.jsonmerge.driver` pointing at the installed
  `json-merge.sh`.
- Installs `json-merge.sh` (jq deep-merge: objects merge, arrays concat+unique, scalar conflicts
  favor incoming) to `~/.dotsync/bin/`.

## Menu-bar UI (MenuBarExtra)

- Status icon reflects aggregate state: idle / syncing / conflict (badge).
- Root list; each row shows last sync time, ahead/behind, pending count, conflict flag, a
  sync-now button, and an auto toggle.
- "What's syncing": live pending files for a root from `git status --porcelain`.
- Rules editor: per-root sheet to edit `.gitignore` / `.gitattributes`, with a preview before
  save (dry-run `git check-ignore` / `git ls-files`) so a bad pattern can't silently break sync.
- Conflicts view: list `sync-conflict-*` branches, show diff, resolve or discard.
- Settings: add root via folder picker, run discover, set intervals.

## Background execution & distribution

- A LaunchAgent plist runs `dotsync daemon`, which drives the scheduler and file watchers for
  `trigger: scheduler` roots without the menu-bar app open.
- The Claude Stop-hook is reduced to `exec dotsync sync claude`, replacing the current bash sync.
- `UserNotifications` alerts on conflict or push failure.
- Distribution v1: unsigned local `.app`; `dotsync` symlinked into `~/.dotsync/bin` (on PATH for
  hooks and the daemon).

## Auto-discover

`dotsync discover` scans the home directory for git-backed dotdirs (a directory whose name starts
with `.` or is a known tool dir, containing a `.git`) and proposes them as candidate roots. The
user confirms before any root is added to `config.json`.

## Testing

- `DotSyncCore`: unit tests against temporary git repositories, using a local bare repo as the
  remote. Cover: happy-path sync, residual conflict → backup branch + remote-wins, JSON
  deep-merge, memory union, lock contention (second concurrent sync skips).
- `DotSyncCLI`: golden tests on `--json` output and exit codes.
- `DotSyncApp`: kept thin; minimal UI tests since logic lives in Core.

## Build phases

- **M1** - `DotSyncCore` + `DotSyncCLI` (`sync`, `status`, `init`). Migrate the Claude Stop-hook
  to call `dotsync sync claude`. Headless; already a clean replacement for the current bash.
- **M2** - MenuBarExtra viewer: aggregate status, per-root rows, sync-now, live pending files.
- **M3** - Multi-root config + auto-discover + scheduler + LaunchAgent daemon; onboard Codex.
- **M4** - Rules editor (with preview) and conflicts view (the control-panel power features).

## Open questions

- None blocking. Distribution hardening (signing/notarization) deferred beyond v1.
