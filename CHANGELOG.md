# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0](https://github.com/akira-foundation/dotsync/releases/tag/v0.1.0) (2026-08-31)

### Features

- **core:** Dotfiles sync engine, gh bridge and secret guards ([f403fb1](https://github.com/akira-foundation/dotsync/commit/f403fb1d193efecb89b5ce23259f9694f23ccec9))
- **app:** Liquid glass menubar with onboarding and auto-sync ([93a0e11](https://github.com/akira-foundation/dotsync/commit/93a0e11e3fe5febdb217045a1eb5d9dd7537b154))
- **core:** Root management helpers and watch setting ([ae51c31](https://github.com/akira-foundation/dotsync/commit/ae51c3124dc0dbfb586cf738644085c2a4f9ca0d))
- **app:** Manage roots, sync-time secret gate, file watch and status badge ([14eee77](https://github.com/akira-foundation/dotsync/commit/14eee77bbdfc06509fd31e8861ac0f8a1b52b3e4))
- **app:** Actionable secret block with reveal and ignore ([95faa63](https://github.com/akira-foundation/dotsync/commit/95faa633a9491ff3e68256030c5737ef96d539c5))
- **core:** Conflict resolver for sync backups ([5ad5aa9](https://github.com/akira-foundation/dotsync/commit/5ad5aa940515f28a30583009c5440a2d237e004c))
- **app:** Conflict resolution UI and header cleanup ([182e967](https://github.com/akira-foundation/dotsync/commit/182e9679f4d79b42ad54b797f3aa4099b13c190c))
- **core:** Wider agent discovery and sendable sync result ([d8bd30f](https://github.com/akira-foundation/dotsync/commit/d8bd30f3d01cfe3203aca305fe5d4b7f6a93064c))
- **app:** Sync notifications, wider discovery, reveal and ui polish ([86f03e0](https://github.com/akira-foundation/dotsync/commit/86f03e03859bdad8f3563d904781b40572f5435c))
- **crypto:** Age wrapper and recipient list ([295b367](https://github.com/akira-foundation/dotsync/commit/295b36716ff253d2f1de9a4aa0dca94a3e8314e7))
- **crypto:** Encryption coordinator and age-aware allowlist ([3794ef0](https://github.com/akira-foundation/dotsync/commit/3794ef0a8473c2735dc5bab20a57c17ab424c929))
- **crypto:** Encryption settings block ([e5fec83](https://github.com/akira-foundation/dotsync/commit/e5fec83f01de7ce5ffd1de2e1bf2a6d7ecceb9ed))
- **app:** Age encryption of synced secrets ([7d81035](https://github.com/akira-foundation/dotsync/commit/7d81035791fb0cc442ddb8ddc807019be122ec19))
- **core:** Ignored discovery paths ([a0b4420](https://github.com/akira-foundation/dotsync/commit/a0b44204a0306fea0c35b12f9234f211ef1991d2))
- **app:** Tame file-watch, confirm removal, fix flood, polish menu ([b0f2c8b](https://github.com/akira-foundation/dotsync/commit/b0f2c8b72f7eb7a46b5ce46b8a47a40a6b675c0c))
- **app:** Sparkle auto-update ([dac8a46](https://github.com/akira-foundation/dotsync/commit/dac8a46659e359588cb26cac0174b5c9bf8badc3))
- **core:** Sync history and pending path listing ([365c7f5](https://github.com/akira-foundation/dotsync/commit/365c7f5810c5c8c7af167a4457b1265d16510cfd))
- **app:** Expandable row detail and anchored popover ([30377a3](https://github.com/akira-foundation/dotsync/commit/30377a37cbe829508bca1085cbffc588251cfd43))
- **core:** Structured logging for silent failures ([c10adde](https://github.com/akira-foundation/dotsync/commit/c10adde368b2c734bb3d12ee56060e4f9891d890))
- **app:** Log viewer window, popover guard and tag-driven version ([479bd74](https://github.com/akira-foundation/dotsync/commit/479bd747b177efb67f3ea5464a40a5b027a9e10f))
- **app:** Native log window ([94164e9](https://github.com/akira-foundation/dotsync/commit/94164e9372c7d36c8df1fa0e10a2b5b5008dc8af))
- **app:** Grouped card ui for settings and roots ([c70a430](https://github.com/akira-foundation/dotsync/commit/c70a4309217fd74facb8a7e2536cc52a92e925c1))


### Bug Fixes

- **core:** Require key body in private-key scan, add scanner allowlist ([0491918](https://github.com/akira-foundation/dotsync/commit/04919182c77414a114b0246efcf8a92351fc44b8))
- **crypto:** Skip re-encryption when plaintext is unchanged ([5cce184](https://github.com/akira-foundation/dotsync/commit/5cce1843fdc398fc1a405af675236cee0874a6ef))
- **crypto:** Write age blobs atomically ([30756a3](https://github.com/akira-foundation/dotsync/commit/30756a3980eea143dad81609cc3fcf2796f95ea8))
- **ci:** Select the newest installed xcode ([c8fd7b2](https://github.com/akira-foundation/dotsync/commit/c8fd7b246a43e289d2518f88a5b80eacc66e9170))
- **app:** Keep the popover open during onboarding dialogs ([6498560](https://github.com/akira-foundation/dotsync/commit/6498560ad7ad9d55f242dc3f25d2500e6c65041e))

