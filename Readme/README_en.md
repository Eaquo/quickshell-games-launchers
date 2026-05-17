# Quickshell Game Launcher

A game launcher built for Hyprland, using Quickshell (Qt6/QML) and a Python backend.
The idea: a fast, good-looking interface that fits your setup — automatic covers, adaptive theming via wallust, keyboard navigation.

[![Watch demo](asset/image.png)](asset/Quickshell-game.mp4)

![screenshot](asset/image.png)
![screenshot 2](asset/image_2.png)

---

## What it does

- Auto-detects your **Steam** games by scanning `.acf` files
- Supports **Heroic Games Launcher** (Epic, GOG, Amazon, sideload)
- Downloads covers from **SteamGridDB** (animated heroes, grids, logos)
- Adaptive theme via **wallust** — colors follow your wallpaper
- Full keyboard navigation (arrows, Enter, Escape, live search)
- Manual games configurable in TOML
- Image cache with configurable TTL

---

## Installation

### Dependencies

```bash
# Quickshell
yay -S quickshell-git

# Python
sudo pacman -S python python-toml python-requests
```

### Setup

```bash
git clone ... ~/.config/quickshell/game-launcher
cd ~/.config/quickshell/game-launcher
```

Test that the backend runs:

```bash
python3 modules/service/backend.py
```

You should see a JSON with your games.

### Hyprland keybind

In `~/.config/hypr/hyprland.conf`:

```conf
bind = SUPER, G, exec, ~/.config/quickshell/game-launcher/toggle.sh
```

---

## Configuration

Everything lives in `config.toml` at the project root.

### Display

```toml
[display]
position = "bottom"          # center, top, bottom
orientation = "horizontal"
grid_size = [3, 1]           # [columns, rows]
item_width = 400
item_height = 200
spacing = 20
```

### Steam

```toml
[steam]
enabled = true
library_paths = [
    "~/.local/share/Steam/steamapps",
    "~/.var/app/com.valvesoftware.Steam/data/Steam/steamapps",  # Flatpak
    # "/mnt/games/SteamLibrary/steamapps",                      # external drive
]
```

### Heroic (Epic / GOG / Amazon)

```toml
[heroic]
enabled = true
config_paths = ["~/.config/heroic"]
scan_epic = true
scan_gog = true
scan_amazon = true
scan_sideload = true
```

### Appearance & wallust

```toml
[appearance]
use_wallust = true
wallust_path = "~/.cache/wal/wal.json"
show_game_names = true
blur_background = true
background_opacity = 0.85
```

### Filtering

Exclude categories or keywords to remove Steam tools from cluttering your list:

```toml
[filtering]
exclude_categories = ["desktop"]
exclude_keywords = ["Launcher", "Manager", "Runtime", "SDK", "Tool"]
```

---

## SteamGridDB

SteamGridDB is a community database of visual assets for games — heroes, grids, logos, icons. Much richer than the base Steam CDN, especially for non-Steam games or animated covers.

### Getting an API key

1. Create an account at [steamgriddb.com](https://www.steamgriddb.com)
2. Go to **Preferences → API** (or directly `/profile/preferences/api`)
3. Generate a key and paste it into `config.toml`

### Configuration

```toml
[steamgriddb]
enabled = true
api_key = "your_key_here"

# Main image type
# "hero"  → wide horizontal banner (1920×620)
# "grid"  → vertical cover Steam-style (600×900)
# "logo"  → transparent PNG logo
image_type = "hero"

# Prefer animated versions (WebP/APNG) when available
prefer_animated = true

# Sort by likes — picks the most popular image first
sort_by_likes = true

# Minimum likes filter (0 = accept everything)
min_likes = 0

# Performance: parallel requests
parallel_requests = true
max_workers = 12
request_timeout = 3      # seconds before timeout

# Local cache: avoids re-downloading on every launch
cache_ttl_hours = 48
```

### How it works

The backend searches by game name via the SteamGridDB API, retrieves the list of available images, sorts them by likes, and downloads the best one. Images are cached locally in `~/.cache/quickshell/game-launcher/`.

If no image is found on SteamGridDB, the launcher automatically falls back to the Steam CDN (`library_600x900.jpg`), then to a placeholder with the game's initials.

### Image types compared

| Type | Dimensions | Use case |
|------|------------|----------|
| `hero` | 1920×620 | Wide banner, looks great in horizontal layout |
| `grid` | 600×900 | Vertical cover, ideal for grid view |
| `logo` | variable (transparent PNG) | Overlay on a custom background |

---

## Manual games

To add a game (or any app) not in Steam/Heroic:

```toml
[[entries]]
title = "Heroic Games"
launch_command = "heroic"
path_box_art = "heroic.png"  # relative to box_art_dir

[[entries]]
title = "📚 Game Library"
launch_command = "kitty -e python3 ~/.config/quickshell/game-launcher/modules/service/list_games.py"
path_box_art = "library.png"
```

Manual covers go in the folder defined by `box_art_dir` (default: `~/.config/quickshell/game-launcher/box-art`).

---

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| `SUPER + G` | Open / Close the launcher |
| `↑ ↓ ← →` | Navigate the grid |
| `Enter` | Launch selected game |
| `Escape` | Close |
| `/` or `F` | Focus search bar |
| Double-click | Launch a game |

---

## Project structure

```
game-launcher/
├── shell.qml                      # Quickshell entry point
├── config.toml                    # Main config
├── requirements.txt
├── toggle.sh                      # Toggle show/hide
├── modules/
│   ├── GameLauncher.qml           # Main component + grid
│   ├── GameCard.qml               # Individual game card
│   ├── LaunchOverlay.qml          # Launch overlay
│   └── service/
│       ├── backend.py             # Steam/Heroic scan, SteamGridDB, TOML
│       ├── gamepad.py             # Gamepad support
│       ├── list_games.py          # Library display
│       └── py_vdf_list.py
├── box-art/                       # Manual covers
├── cache/                         # SteamGridDB image cache
└── Readme/
    ├── README.md
    ├── README_en.md
    └── asset/
        ├── Quickshell-game.mp4
        ├── image.png
        └── image_2.png
```

---

## Troubleshooting

**Launcher doesn't open**
```bash
quickshell -c ~/.config/quickshell/game-launcher/shell.qml
# Check for errors in the terminal
```

**No Steam games detected**
```bash
ls ~/.local/share/Steam/steamapps/*.acf
# Make sure the path in config.toml matches
```

**SteamGridDB covers not loading**
- Check that your API key is correct
- Look at `cache/image_cache.json` to see resolved URLs
- Increase `request_timeout` if your connection is slow

**Error `No module named 'toml'`**
```bash
pip install toml
# or
sudo pacman -S python-toml
```

---

## Credits

Inspired by [caelestia-dots/shell](https://github.com/caelestia-dots/shell)

Built with:
- [Quickshell](https://github.com/outfoxxed/quickshell) — Qt6/QML for Wayland
- [SteamGridDB](https://www.steamgriddb.com) — visual asset API
- [Wallust](https://codeberg.org/explosion-mental/wallust) — colorschemes from wallpaper
- Python 3 + TOML
