# Security Policy

## Reporting a vulnerability

Please report security vulnerabilities by email to
[kidiatoliny@gmail.com](mailto:kidiatoliny@gmail.com). Do not open a public issue.

We will acknowledge receipt within 72 hours and will provide a more detailed response within
7 days indicating the next steps.

## Scope

dotsync moves configuration folders into git repositories and pushes them to GitHub, so the
issues that matter most are the ones that could expose data that should have stayed local:

- A path where a credential file or secret becomes tracked in clear text.
- An allowlist template that admits files it should ignore.
- A secret scanner bypass that lets a tracked secret reach a push.
- Any code path that creates a public repository, or pushes without confirmation.
- A weakness in the age encryption flow, including key handling in the Keychain or the
  recipient list.

## Disclosure policy

We follow coordinated disclosure. After a fix is released, we will publish a security advisory
on GitHub with credit to the reporter, unless they prefer to remain anonymous.

## Supported versions

| Version | Status |
|---------|--------|
| Latest  | Supported |
| Older   | Best-effort backports for critical issues |
