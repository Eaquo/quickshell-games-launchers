# Changelog

All notable changes to this project will be documented in this file.

## [2.1.0] — 2026-09-28

### Added
- **Daemon mode** — the launcher starts hidden and `SUPER+G` toggles it instantly (see README for `exec-once`)
- **Animated gradient border** around the launcher and the search bar, with a toggle in ConfigPanel
- **Big Picture in HD** — background always uses SteamGridDB heroes (up to 3840×1240), plus an animated hero when available
- `max_animated_mb` option (default 50) — skip animated covers heavier than this
- `cache_in_memory` option — keep animated covers in RAM (#14 by @Diego0160)
- Both options available in ConfigPanel; number fields (cache TTL, workers, timeout) editable with the keyboard

### Fixed
- Animated covers not showing: the image cache could be wiped and re-downloaded on each selection
- Animated PNG covers displayed as still images — animations are now WebP only
- Animated covers fetched for games that already have a local cover (PortProton, shortcuts)
- Big Picture: smooth cross-fade between slides, better fallback image without an SGDB key
- Launcher only appears on the focused monitor
- Steam and Heroic launch without opening their client window
- Saving the config now reloads the game list
- Config migration adds new keys to the right section
- Game names containing `/` no longer break the SGDB search (#14 by @Diego0160)
- Oversized images (e.g. a 13471×6421 logo) are skipped

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
- Path list editor for Steam library paths and Heroic config paths — add/remove individual paths with × button
- Manual entries editor in ConfigPanel — master-detail layout, title/command/cover per entry, add/delete
- `cfg_path_add` i18n key in all 5 languages
- JPEG cover art priority — same visual quality as PNG at 3-10x smaller file size

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
