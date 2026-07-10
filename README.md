# Uninstally

[![Release](https://img.shields.io/github/v/release/gostonx/uninstally)](https://github.com/gostonx/uninstally/releases/latest)
[![Homebrew Cask](https://img.shields.io/badge/Homebrew-Cask-blue?logo=homebrew)](https://github.com/gostonx/uninstally/releases/latest)
[![License](https://img.shields.io/github/license/gostonx/uninstally)](LICENSE)

Uninstally is a native macOS uninstaller built with SwiftUI. Remove apps and their leftover files, manage Homebrew packages, and uninstall directly from Finder with a simple right click.

<p align="center">
  <img src="docs/uninstally-demo.gif" alt="Uninstally demo — uninstalling an app and its leftover files" width="80%" />
</p>

Quick links: [Download](https://github.com/gostonx/uninstally/releases/latest) · [Changelog](CHANGELOG.md) · [Docs](docs/) · [Website](https://codenta.us/)

---

## Table of contents

- [Quick start](#quick-start)
- [Requirements](#requirements)
- [Install](#install)
- [First launch & Gatekeeper](#first-launch--gatekeeper)
- [Build & run (developer)](#build--run-developer)
- [Features](#features)
- [Troubleshooting](#troubleshooting)
- [Releases & updates](#releases--updates)
- [Architecture & internals](#architecture--internals)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)

---

## Quick start

Install (Homebrew, recommended)

```sh
brew tap gostonx/tap
brew install --cask uninstally
```

Or download the latest DMG from Releases and drag to /Applications.

Open the app, grant Full Disk Access for deepest scans, then right‑click any `.app` in Finder → "Uninstall with Uninstally" to run a confirmation + removal flow.

---

## Requirements

- macOS 14.0 or later (built against macOS 26 SDK / Xcode 26)
- Xcode 16 or later (for building from source)

---

## Install

### Homebrew (recommended)

```sh
brew tap gostonx/tap
brew install --cask uninstally
```

Uninstall / update:

```sh
brew upgrade --cask uninstally
brew uninstall --cask uninstally
brew uninstall --cask --zap uninstally   # remove app + leftovers
```

### Direct download

Get Uninstally.dmg from the Releases page, open it, and drag **Uninstally** into **Applications**.

---

## First launch & Gatekeeper

Unsigned/ad-hoc builds may be blocked by Gatekeeper. To open:

- Right-click the app → Open → confirm
- or clear quarantine:

```sh
xattr -dr com.apple.quarantine /Applications/Uninstally.app
```

If the Finder extension does not appear, run the app once (so Launch Services registers it), then enable the extension in System Settings → General → Login Items & Extensions → Finder Extensions.

---

## Build & run (developer)

Open the Xcode project and run the `Uninstally` scheme (⌘R), or build from the command line:

```bash
xcodebuild -project Uninstally.xcodeproj -scheme Uninstally \
  -configuration Debug -destination 'platform=macOS' build
```

Notes:
- Project is configured for ad-hoc signing for local builds (`CODE_SIGN_IDENTITY = "-"`). For distribution set `DEVELOPMENT_TEAM` and enable automatic signing.
- For distribution the project uses Sparkle and an appcast; see `docs/UPDATES.md` for update signing & channels.

### Enabling the Finder extension

1. Run the app once so Launch Services registers it.
2. Open System Settings → General → Login Items & Extensions → Finder Extensions and enable **Uninstally Finder**.
3. Right-click any `.app` bundle to see **"Uninstall with Uninstally"**.

### Full Disk Access

Grant Full Disk Access (System Settings → Privacy & Security) to allow deep scans of protected locations.

---

## Features

- Finder right-click integration to start uninstall flows
- Smart identifier-driven detection (bundle identifier + helper namespaces)
- Standalone browser: searchable grid/list of installed apps with rich filters
- Batch uninstall and aggregate storage reclaim summaries
- Leftover scanner for orphaned support files, caches, containers, preferences, logs, and installers
- Homebrew cask/formula listing and uninstall (optional `--zap`)
- Safe removal: user files → Trash; privileged removals behind single elevated prompt
- Polished SwiftUI interface with VoiceOver labels, keyboard shortcuts, and native animations
- Automatic updates via Sparkle with stable / beta / nightly channels

---

## Troubleshooting

- Finder menu item not visible: ensure Finder Extensions are enabled and restart Finder (Option‑right‑click Finder icon → Relaunch).
- Gatekeeper blocks unsigned build: use the right‑click → Open flow or xattr command above.
- Leftover scan finds many items: review matched items and their matching reasons before proceeding; items are deselectable in the confirmation UI.
- Homebrew cask not shown: ensure Homebrew is installed and accessible in the current PATH the app uses (relaunch app after installing Homebrew).

---

## Releases & updates

Releases are automated: tags trigger CI to build, sign, notarize and publish. See `docs/RELEASING.md` and `docs/UPDATES.md` for the publishing flow, Sparkle configuration, and key rotation.

---

## Architecture & internals

Short overview:
- MVVM, Swift concurrency (`async/await`, `AsyncStream`)
- Scanners: `ApplicationScanner`, `AssociatedFileScanner`, `LeftoverScanner`
- Engine: `UninstallEngine` — Trash + elevated removal with streamed progress
- Integration: `HomebrewService` and Finder Sync extension

See `docs/ARCHITECTURE.md` for detailed design, file layout, and matching strategy.

---

## Contributing

Contributions welcome. Please read `CONTRIBUTING.md` (if present) or follow these basics:
- Fork → branch named `feat/...` or `fix/...` → open a PR
- Run tests / Xcode build locally before opening a PR
- Keep changes focused and document behaviour changes in a short PR description

---

## Security

If you discover a security vulnerability, please report it privately (see `SECURITY.md` if present) or contact the maintainers via the repository's security policy.

---

## License

See the LICENSE file for details.

---
## Changelog

Full changelog: [CHANGELOG.md](CHANGELOG.md)
