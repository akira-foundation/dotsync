# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Menu bar app for macOS 26 on Apple Silicon, with per-folder status, pending file lists and
  recent sync history.
- Discovery of known agent folders and onboarding that runs `git init`, writes a per-tool
  allowlist, and creates a private GitHub repository through `gh`, confirming every outward step.
- Secret scanning that blocks a sync when a tracked file contains a key or token, with per-file
  ignores for false positives.
- Optional age encryption of credential files, using one key pair per machine and a registered
  recipient list, so no private key is ever copied between Macs.
- Automatic syncing on an interval or on tracked file changes, plus launch at login.
- Conflict resolution over the sync backup branch.
- Log window with filtering, copy and save, backed by structured logging in the core.
- Sparkle auto-updates from a signed and notarized release.

[Unreleased]: https://github.com/akira-foundation/dotsync/commits/main
