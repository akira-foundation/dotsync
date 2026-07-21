# Contributing to dotsync

Thanks for your interest in contributing.

## Bugs and feature requests

Open an issue at https://github.com/akira-foundation/dotsync/issues. Include:

- What you expected to happen.
- What actually happened.
- A minimal reproduction.
- Versions: dotsync, macOS, and the output of `swift --version`.

## Working on a pull request

1. Fork the repo and create a branch from `main`.
2. Add tests for the change. Logic belongs in `DotSyncCore`, which is the tested layer;
   the app target is a thin AppKit and SwiftUI shell.
3. Run the checks below before pushing.
4. Use conventional commit messages with a scope, for example `feat(core): ...`.
5. Open the PR against `main`. Keep the diff focused: refactors, feature work, and
   dependency bumps belong in separate PRs.

```sh
swift build --arch arm64
swift test --arch arm64
bash scripts/format.sh --lint
```

`bash scripts/format.sh` rewrites files in place using the project `.swift-format`
configuration. CI runs the same commands on macOS 26.

## Style

- Match the existing project conventions; the formatter output is the source of truth.
- Source files stay under 300 lines. Split into extensions or new types instead of growing one.
- No narrative comments. Names carry the meaning.
- No drive-by refactors in feature PRs.
- No emojis in code, copy, commit messages, or PR descriptions.

## Security-sensitive changes

Anything touching the allowlist templates, the secret scanner, or the encryption path changes
what can leave a user's machine. Those pull requests need a test that proves the new behaviour
and an explanation of the threat it addresses. Do not weaken a guard to make a test pass.

## License

By contributing, you agree that your contributions will be licensed under the MIT License, as
described in [LICENSE](LICENSE).
