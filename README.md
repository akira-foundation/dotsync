# dotsync

Keep your AI agent configuration folders in sync across Macs, using git you already
understand and a private GitHub repository per folder.

dotsync lives in the menu bar. It finds folders like `~/.claude` and `~/.codex`, turns
each one into a git repository with a secret-safe ignore list, creates a private GitHub
repository for it, and keeps every machine up to date. Credentials never travel in clear
text: they are either excluded or encrypted with age.

## Requirements

- macOS 26 or later, Apple Silicon
- `git`
- [`gh`](https://cli.github.com) authenticated (`gh auth login`) for repository creation
- [`age`](https://github.com/FiloSottile/age) if you enable secret encryption
  (dotsync offers to install it through Homebrew)

## Install

Download the latest signed and notarized `.dmg` from
[Releases](https://github.com/akira-foundation/dotsync/releases), drag the app to
`/Applications`, and launch it. Updates arrive automatically through Sparkle.

## How it works

**Discovery.** On launch dotsync looks for known agent folders (`~/.claude`, `~/.codex`,
`~/.gemini`, `~/.aider`, `~/.continue`, `~/.cursor`) plus anything you add yourself.
Folders you remove are remembered and never re-added.

**Onboarding.** For a folder that is not a repository yet, dotsync runs `git init`, writes
a per-tool allowlist, scans for secrets, then creates a private GitHub repository and
pushes. Every outward step asks first: no repository is created and nothing is pushed
without a confirmation.

**Allowlist before anything else.** The generated `.gitignore` ignores everything and then
re-enables only real configuration. Session transcripts, caches, logs and credential files
never enter the index. The rules differ per tool, because `~/.claude` and `~/.codex` do not
share a layout.

**Secret scanning.** Before every push the tracked file set is scanned for API keys,
tokens and private keys. A hit blocks the sync and tells you which file is responsible.
False positives can be ignored per file from the alert.

**Encryption.** With encryption enabled, credential files are encrypted with age instead of
being skipped, so they sync too. Each machine holds its own key pair: the private key stays
in that machine's Keychain, the public key is registered in the repository. Files are
encrypted to every registered machine, so adding a Mac never means copying a private key.

**Syncing.** Configuration merges rather than overwrites: markdown and JSONL use a union
merge, JSON files use a structural merge driver. If a real conflict happens, your version is
saved on a backup branch and the row offers to resolve it.

**Triggers.** Sync runs on an interval, on file changes, or on demand. File-change syncing
only fires when git reports tracked changes, so background noise does not cause commits.

## Security model

- Repositories are always private. There is no code path that creates a public one.
- Credential files (`.credentials.json`, `auth.json`, `*.local.json`) are never tracked in
  clear text. They are ignored, or encrypted with age.
- The secret scanner blocks the sync instead of warning.
- Creating a repository and the first push always require explicit confirmation.
- The GitHub account and host are chosen by you and pinned for every `gh` call.

## Settings

Configuration lives in `~/.dotsync/settings.json`, and the roots list in
`~/.dotsync/config.json`. Everything is editable from the Settings panel: GitHub account,
repository naming, discovery, sync interval, file watching, launch at login and encryption.

## Build from source

```bash
git clone https://github.com/akira-foundation/dotsync.git
cd dotsync
swift build -c release --arch arm64
bash scripts/bundle.sh     # assembles DotSyncApp.app
swift test --arch arm64
bash scripts/format.sh     # swift-format
```

## License

MIT. See [LICENSE](LICENSE).
