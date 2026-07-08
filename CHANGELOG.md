# Changelog

All notable changes to Uninstally are documented here. This project follows
[Semantic Versioning](https://semver.org/) and its releases are published on the
[Releases page](https://github.com/gostonx/uninstally/releases).

## [1.2.0] — 2026-07-08

### Added
- **Haptic feedback.** Subtle, native trackpad feedback when selecting items,
  moving between sidebar sections/Settings tabs, reaching the top or bottom of a
  list, and reordering. Restrained by design (never continuous), and a no-op on
  hardware without a Force Touch trackpad.
- **Customizable Settings tabs.** A new **Customize Settings** screen lets you
  reorder tabs by drag-and-drop, rename them, and enable/disable them. Your
  layout is saved and restored across launches.
- **Reorganized Settings** into tabs: General, Updates, Appearance, Advanced and
  About.
- **Software update check** in the Updates tab that compares the installed
  version against the latest GitHub release.
- **"Enable Haptic Feedback"** toggle (General).

## [1.1.0] — 2026-07-08

### Added
- **Show icon in Dock** toggle in Settings — run Uninstally as a lightweight
  accessory (default) or as a regular app with a Dock icon and menu bar.

## [1.0.0] — 2026-07-08

### Added
- Initial release.
- Finder integration: right-click any `.app` bundle → **Uninstall with
  Uninstally**.
- Smart, bundle-identifier-driven detection of associated files across the macOS
  Library hierarchy.
- Standalone application browser with search, sorting and smart filters.
- Batch uninstall, leftover scanner, and Homebrew package support.
- Progress, safety confirmation and completion screens.

[1.2.0]: https://github.com/gostonx/uninstally/releases/tag/v1.2.0
[1.1.0]: https://github.com/gostonx/uninstally/releases/tag/v1.1.0
[1.0.0]: https://github.com/gostonx/uninstally/releases/tag/v1.0.0
