# dotsync - Onboarding + GitHub provisioning (design)

Date: 2026-07-20
Status: approved (decisions locked), pending implementation
Depends on: 2026-07-20-dotsync-design.md (core sync engine)

## Goal

dotsync auto-discovers agent config dirs (`~/.claude`, `~/.codex`), and for each:
git-inits if needed, writes a secret-safe allowlist, verifies/creates a **private**
GitHub repo via `gh`, and links + pushes - every outward step gated by an in-app
confirmation. Behavior is fully configurable via a settings file.

## Locked decisions

1. **One repo per folder** - `dotsync-claude`, `dotsync-codex` (isolated blast radius).
2. **Ask before creating remote** - confirmation dialog before every `gh repo create`
   and first `push`. No silent outward actions.
3. **Block on secret** - if a secret is found in the tracked set, stop the sync,
   report the offending file, require user action.

## Threat model (must hold)

- **Secrets never leave the machine unintentionally.** `~/.claude/.credentials.json`,
  `~/.codex/auth.json`, `projects/**` transcripts, `history.jsonl`, MCP API keys.
  Guards: allowlist `.gitignore` written BEFORE first `git add`; private-only repos;
  pre-commit secret scan that blocks; refuse push if credential files are tracked.
- **Wrong GitHub account.** User explicitly selects the `gh` account/host in settings;
  every `gh` call is pinned to that host. Never infer.
- **Public exposure.** `visibility` is locked to `private`; no code path creates a
  public repo.
- **Re-init / nested repo.** Detect existing `.git`; never re-init. Detect home-is-repo
  nesting and warn.
- **Data loss.** Config conflicts resolved by merge drivers (core spec), never
  force-overwritten. First commit is allowlisted, so no GB-scale transcript dump.

## Settings (`~/.dotsync/settings.json`)

```jsonc
{
  "github": {
    "host": "github.com",
    "account": "kidiatoliny",           // chosen from `gh auth status`
    "visibility": "private",            // LOCKED
    "repoNameTemplate": "dotsync-{id}",
    "autoCreateRemote": false           // ask-always
  },
  "discovery": {
    "enabled": true,
    "autoAdd": true,
    "paths": ["~/.claude", "~/.codex"]
  },
  "guards": {
    "requirePrivate": true,             // not user-disablable
    "secretScan": true,
    "blockOnTrackedSecrets": true
  }
}
```

`defaults` (branch, intervalSec) stays in `config.json` (core). Settings is separate so
UI can edit it without touching the roots list.

## Onboarding state machine (per discovered/added root)

```
discover path (~/.claude, ~/.codex)
  exists? no  -> skip
  is git repo? no -> [confirm] git init
  write allowlist .gitignore + .gitattributes (merge drivers)   <- BEFORE any add
  secret scan working tree
     secret in tracked set -> BLOCK, report file, stop
  has remote origin?
     no -> gh repo view <account>/<name> (on chosen host)
              exists -> [confirm link] git remote add origin <url>
              missing -> [confirm] gh repo create <account>/<name> --private
  [confirm] initial commit + push -u origin <branch>
  record root in config.json
```

Every `[confirm]` is an in-app dialog. Abort at any step leaves the folder untouched
(idempotent: re-running resumes where it stopped).

## Allowlist template (written per root before first add)

```gitignore
/*
/.*
!/.gitignore
!/.gitattributes
!/CLAUDE.md
!/settings.json
!/keybindings.json
!/skills/
!/agents/
!/commands/
!/plugins/
/plugins/*
!/plugins/config.json
!/plugins/repos/
.credentials.json
auth.json
settings.local.json
```

`.gitattributes` carries the merge drivers (`merge=union` for md/jsonl/memory,
`merge=jsonmerge` for json) from the core spec.

## Secret scan

- Prefer `gitleaks detect --no-git` on the working tree if installed.
- Fallback: built-in regex over the tracked (allowlisted) set only:
  `sk-[A-Za-z0-9]{20,}`, `ghp_[0-9A-Za-z]{36}`, `xox[baprs]-`, PEM headers,
  JSON keys `token|secret|password|apiKey` with non-empty string values.
- Hard block: if `.credentials.json` / `auth.json` / `*.local.json` appear in
  `git ls-files`, refuse (they should be gitignored; presence means the allowlist failed).

## `gh` bridge (new, isolated like payable rule - gh only inside a GhBridge type)

- `gh auth status --json` → enumerate logged-in hosts/accounts for the settings picker.
- `gh api user --hostname <host>` → validate + display login.
- `gh repo view <owner>/<name> --hostname <host>` → existence check (exit code).
- `gh repo create <owner>/<name> --private --hostname <host>` → create (no `--source`,
  we push manually after allowlist + scan).
- Missing `gh` binary or missing `repo` scope → surfaced as a clear, actionable error.

## Slices

- **M3a Settings**: settings.json load/save + menubar Settings panel (gh account picker,
  discovery toggles, guards shown read-only).
- **M3b Discovery**: on launch, scan `discovery.paths`, propose/add missing roots.
- **M3c Onboarding**: the state machine, with confirmation dialogs.
- **M3d Secret scan**: guard (gitleaks + fallback), wired into onboarding and sync.
- **M3e gh bridge**: the `GhBridge` wrapper + error surfacing.

## Non-goals (this milestone)

- GitLab/Bitbucket providers (GitHub-only via gh for now).
- Automatic secret rotation.
- Conflict-resolution UI (that's M4).
