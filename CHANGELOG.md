# Changelog

All notable changes to Uninstally are documented here. This project follows
[Semantic Versioning](https://semver.org/) and its releases are published on the
[Releases page](https://github.com/gostonx/uninstally/releases).

## [1.5.0] — 2026-07-09

### Added
- **Recently Uninstalled** — a new sidebar section showing an uninstall history of
  apps you removed with Uninstally (with a live count). Stored locally with
  SwiftData; nothing is uploaded and no analytics are collected.
  - Each entry records the app name, icon, developer, version, bundle identifier,
    original location, date/time, files removed, storage recovered, and deletion
    method (Trash or Permanent).
  - **Statistics** at the top: total apps uninstalled, total storage recovered,
    last uninstall, and average space recovered.
  - **Search** by app name, developer or bundle identifier, and **filters** for
    Today, Last 7 Days, Last 30 Days, All Time, Trash, and Permanent Delete.
  - **Actions**: Restore from Trash (when the item is still in the Trash), View
    Details, Reveal Original Location, Remove From History, and Clear History.
  - Hide or show the section from the sidebar customization.
- **History settings** — Keep Uninstall History (on by default), History Retention
  (30 Days / 90 Days / 1 Year / Forever), and Clear History.

## [1.4.5] — 2026-07-09

### Added
- **Uninstall behavior setting** — choose how removed files are disposed of:
  **Move to Trash** (default, recoverable) or **Permanently Delete**. The choice
  is shown clearly in the confirmation ("…move this app and N related files to
  Trash" vs. a permanent-delete warning with a **Delete Permanently** button) and
  is remembered across launches.

### Changed
- **Native macOS redesign.** A titled window with a unified toolbar, **translucent
  window materials**, native button and list styles, a Finder-style floating
  sidebar, native grouped Settings sections, and the system typography hierarchy —
  so Uninstally feels at home next to Finder and System Settings.
- **About** now shows a direct link to [codenta.us](https://codenta.us/).

### Fixed
- **Instant UI after uninstalling.** Removing an app no longer triggers a full
  rescan of every installed application, so the removed app disappears
  immediately with a smooth animation (optimistic in-memory update, then a
  Finder-sync nudge) instead of lingering for several seconds.

### Removed
- **Haptic feedback** has been removed entirely. macOS doesn't offer reliable,
  general-purpose haptics for this kind of app, so the feature and its Settings
  toggle are gone. The now-empty General settings section was removed too.

## [1.4.4] — 2026-07-09

### Changed
- The **Settings sidebar now stays visible** and can no longer be collapsed, so
  the section list is always available while browsing preferences.

## [1.4.3] — 2026-07-09

### Added
- **Rename Collections from the sidebar** — right-click any Collection and choose
  **Rename…** (renaming is also still available in the Customize Sidebar sheet).

## [1.4.2] — 2026-07-08

### Added
- **Collections** — create your own tabs in the main sidebar to group and
  categorize apps.

  Collections are great for **trying out apps you plan to remove later**: when you
  download something to test, drop it into a "Trying Out" (or "To Delete")
  Collection so it doesn't get lost among your everyday apps. When you're done
  evaluating, open that Collection and uninstall the app — along with all its
  leftover files — in a couple of clicks. Other handy uses: grouping a project's
  tools, games, or apps you're deciding whether to keep.

  Add apps by dragging them onto a Collection or right-clicking an app →
  **Add to Collection**. Rename, pick an icon, reorder and delete Collections from
  the Customize Sidebar sheet. Collections are organizational only and never
  change what's installed; they persist across launches.

### Changed
- Sidebar customization now lives in the **main application window** (not
  Settings). Settings is a single, fixed page again.

## [1.4.1] — 2026-07-08

### Fixed
- Fixed a crash on launch in 1.4.0 where the main window failed to find the
  Applications sidebar model, preventing the app from opening.
- The window now reliably comes to the front on a normal launch (the app runs as
  a menu-less accessory by default; enable a Dock icon in Settings → Appearance).

## [1.4.0] — 2026-07-08

### Added
- **Automatic updates via Sparkle.** Uninstally now checks for updates on launch
  and every 24 hours, downloads and verifies them securely, and installs with a
  relaunch — all through Sparkle's native UI.
  - Updates are read only from the signed appcast at `https://codenta.us/appcast.xml`
    and must carry a valid EdDSA signature; unsigned or tampered updates are rejected.
  - New **Updates** settings: current/latest version, last checked, update channel,
    automatic check/download toggles, beta updates, and Check Now / Clear Ignored
    Version / Reset Update Preferences.
  - Stable, Beta and Nightly channels.
- **Fully automated release pipeline** (GitHub Actions): pushing a `v*` tag builds,
  tests, signs, notarizes, staples, creates a DMG, generates the appcast, publishes
  the GitHub release, and deploys the website — with zero manual steps.

## [1.3.0] — 2026-07-08

### Changed
- **Settings is now a single, continuous page** (like Apple's System Settings)
  instead of separate panes. The sidebar is used purely for navigation:
  selecting a section smoothly scrolls to it and highlights it, and scrolling
  updates the highlight in return.

### Added
- **Customizable navigation sidebar.** Reorder sections by drag-and-drop, show or
  hide them, and restore the default layout from the new **Customize Sidebar**
  card. Hiding a section only removes it from the sidebar — it still appears on
  the page. The layout persists across launches.
- New sections: **Uninstall Settings**, **Scanning** and **Security**, alongside
  General, Updates, Appearance, Advanced and About.
- Subtle haptic feedback when crossing section boundaries while scrolling.

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

[1.5.0]: https://github.com/gostonx/uninstally/releases/tag/v1.5.0
[1.4.5]: https://github.com/gostonx/uninstally/releases/tag/v1.4.5
[1.4.4]: https://github.com/gostonx/uninstally/releases/tag/v1.4.4
[1.4.3]: https://github.com/gostonx/uninstally/releases/tag/v1.4.3
[1.4.2]: https://github.com/gostonx/uninstally/releases/tag/v1.4.2
[1.4.1]: https://github.com/gostonx/uninstally/releases/tag/v1.4.1
[1.4.0]: https://github.com/gostonx/uninstally/releases/tag/v1.4.0
[1.3.0]: https://github.com/gostonx/uninstally/releases/tag/v1.3.0
[1.2.0]: https://github.com/gostonx/uninstally/releases/tag/v1.2.0
[1.1.0]: https://github.com/gostonx/uninstally/releases/tag/v1.1.0
[1.0.0]: https://github.com/gostonx/uninstally/releases/tag/v1.0.0
