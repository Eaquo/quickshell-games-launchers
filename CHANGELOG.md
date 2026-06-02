# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] — 2026-05-31

### Added
- **ConfigPanel** — graphical settings editor with 9 sections, no TOML editing required
- **Matugen** — Material You theming support, mutually exclusive with Wallust
- **Lutris** — library scanning via `pga.db`
- **i18n in ConfigPanel** — all labels and descriptions translated (fr / en / es / ru / ja)
- **Live palette preview** — 18 color swatches in Appearance section with hex tooltip
- `start_in_bigpicture` config option — open directly in Big Picture on launch
- Config gear button in Big Picture mode
- `F5` keyboard shortcut to refresh game list
- Lazy loading for game cards
- Loading dots animation during game fetch

### Added
- Path list editor for Steam library paths and Heroic config paths — add/remove individual paths with × button
- Manual entries editor in ConfigPanel — master-detail layout, title/command/cover per entry, add/delete
- `cfg_path_add` i18n key in all 5 languages

### Fixed
- CfgText commits value on focus loss, not only on Enter key (API key, paths)
- CfgSlider / CfgSpin / CfgText values now load correctly from config (QML binding preserved)
- Library path textarea (CfgArea) now saves edits correctly
- Close launcher on click outside the dim overlay (was broken syntax)
- Flash of default config on startup suppressed (`configLoaded` gate)
- SteamGridDB covers now fetched for Lutris and manual games (name-search fallback)
- Click outside launcher now quits cleanly (Qt.quit) — no full-screen dim overlay, launcher floats over desktop
- Catch-all MouseArea in GameLauncher and BigPictureView — clicks on empty areas no longer quit the app
- PanelWindow keyboard focus releases correctly when launcher is hidden

### Changed
- Config writes back to TOML preserving comments (`tomlkit`)
- Gear button moved to bottom-right of sidebar, modernized icon
- Removed jarring `Quickshell.reload()` on config save

---

## [1.2.0] — 2025-12-XX

### Added
- Big Picture mode — fullscreen Steam Deck-style view (hero, stats, game strip)
- Internationalization (i18n) — fr / en / es / ru / ja, auto-detected
- State persistence — last active source and game remembered between sessions
- Config migration system — new keys inserted automatically on update
- Animated WebP / WebM cover support via SteamGridDB
- Gamepad support — navigate, launch, favorites, Big Picture via X button
- `F5` refresh, lazy loading, loading dots

---

## [1.0.0] — Initial release

### Added
- Steam library scanning (ACF parser + VDF binary shortcuts)
- Non-Steam games detection via `shortcuts.vdf`
- Heroic Games Launcher support (Epic / GOG / Amazon / Sideload)
- SteamGridDB cover art (static + animated)
- Wallust / pywal theming
- Favorites system
- Live search
- Keyboard and scroll wheel navigation
