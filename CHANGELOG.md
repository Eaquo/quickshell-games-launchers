# Changelog

All notable changes to this project will be documented in this file.

## [2.1.0] — 2026-09-28

### Highlights
- **Instant open** — the launcher now runs as a hidden daemon, `SUPER+G` just toggles it over IPC
- **Sharp Big Picture** — background always uses SteamGridDB heroes (up to 3840×1240) + animated hero
- **Animated covers that actually play** — fixed a cache race that deleted downloaded images

### Added
- **Daemon mode** — Quickshell starts hidden and stays warm; `toggle.sh` switches visibility via `qs ipc call launcher toggle|show|hide` (no cold start, no cover pop-in). See README for the `exec-once` setup
- **Animated gradient border** around the launcher and the search bar (wallust / matugen palette), with an on/off toggle in ConfigPanel
- **Big Picture always uses SteamGridDB heroes** for the background (up to 3840×1240), whatever `image_type` is set for the cards — sharp and correctly framed on wide screens
- **Animated hero** (`hero_animated`) plays as the first Big Picture slide when one exists
- `max_animated_mb` option (default 50) — skip animated covers heavier than this; slider in ConfigPanel
- `[animations] cache_in_memory` option — keep decoded animated frames in RAM (opt-in, #14 by @Diego0160), with a toggle in ConfigPanel
- Number fields in ConfigPanel (cache TTL, workers, timeout) are editable with the keyboard — Enter / focus loss to apply, Esc to cancel, value clamped to its range
- New ConfigPanel labels translated in fr / en / es / ru / ja

### Fixed
- **Animated covers not showing**: concurrent writes to `image_cache.json` could leave it half-written, read back as empty, and the downloader then deleted every cached image — animations were re-downloaded (30-50 MB) on each selection
  - Atomic, thread-safe cache writes (tmp file + rename)
  - Orphan cleanup skips when the cache is empty
  - Single downloader at a time (`flock`), lock taken before cleanup — replaces the PID lock file from #14
  - Downloads written to `.part` then renamed — an interrupted download never leaves a truncated file
  - Downloader output logged to `cache/download-cache.log`
- Animated covers limited to WebP — animated PNG (APNG) was displayed as a still image
- Animated covers now fetched for games that already have a local static image (PortProton, shortcuts)
- Big Picture hero: smooth cross-fade between slides, animated WebP support
- Big Picture without an SGDB key uses Steam `library_hero.jpg` (1920×620) instead of the stretched `header.jpg`
- Launcher only appears on the focused monitor (Hyprland `focusedMonitor`)
- Steam games launch with `-silent`, Heroic with `--no-gui` (no client window popping up)
- Saving the config reloads the game list (daemon mode kept stale images, e.g. after changing `image_type`)
- Config migration is section-aware (a key like `enabled` is added to the right section); `config_writer` writes missing keys of any type
- `steamgriddb.enabled` added automatically to existing configs (SGDB was silently disabled)
- Game names containing `/` no longer break the SGDB search (404) (#14 by @Diego0160)
- Images larger than 4096 px per side are skipped (Qt could not decode e.g. a 13471×6421 logo)
- SGDB ranking reads `upvotes` (the API has no `likes` field); ties broken by resolution
- No negative SGDB cache for games never fetched; null `appid` guarded
- 404 responses from SGDB no longer spam stderr

### Performance
- Card covers decoded at card size (`sourceSize`) instead of full resolution

### Contributors
- @Diego0160 — #14 (downloader lock + logging, SGDB slash encoding, animated RAM cache)

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
