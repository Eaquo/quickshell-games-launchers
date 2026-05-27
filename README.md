<div align="center">

# Quickshell Launchers

**Sleek game launchers for Hyprland with pywal/wallust integration**

[![Stars](https://img.shields.io/github/stars/Eaquo/quickshell-games-launchers?style=for-the-badge&logo=github&color=DEA6FF&labelColor=302D41)](https://github.com/Eaquo/quickshell-games-launchers/stargazers)
[![Hyprland](https://img.shields.io/badge/Hyprland-compatible-89B4FA?style=for-the-badge&logo=wayland&logoColor=white&labelColor=302D41)](https://hyprland.org)
[![AUR](https://img.shields.io/badge/AUR-quickshell--games--launchers--git-F9E2AF?style=for-the-badge&logo=archlinux&logoColor=white&labelColor=302D41)](https://aur.archlinux.org/packages/quickshell-games-launchers-git)

<br>

<table>
<tr>
<td width="50%" align="center">

**📸 Preview**

<img src="Readme/asset/image.png" alt="Game Launcher Preview" width="100%"/>

</td>
<td width="50%" align="center">

**🎬 Demo**

https://github.com/user-attachments/assets/703e48dd-86d1-49cb-8bc8-1fe45b89e9f5

</td>
</tr>
</table>

[**Features**](#-features) · [**Install**](#%EF%B8%8F-installation) · [**Configuration**](#%EF%B8%8F-configuration) · [**Big Picture**](#-big-picture-mode) · [**Gamepad**](#-gamepad)

</div>

---

## 📦 Projects

### 🎮 Game Launcher

Game launcher with multi-platform support and a sleek animated interface.

![Game Launcher](Readme/asset/image_2.png)

## ✨ Features

- 🎯 Support for Steam, non-Steam games, Heroic (Epic/GOG/Amazon), and manual entries
- 🎮 Automatic detection of non-Steam games added to Steam (via shortcuts.vdf)
- 🖼️ Automatic cover art from Steam CDN / SteamGridDB (animated WebP/WebM heroes)
- 🚀 Animated launch overlay — cover expands fullscreen with game logo and "Start Game◦◦◦" indicator
- 📺 **Big Picture mode** — fullscreen Steam Deck-style view with hero image, stats panel, and game strip
- 🕹️ Gamepad support (navigate, launch, favorites, Big Picture toggle via X button)
- 🏷️ Platform badges and categories
- ⭐ Favorites system
- 🆕 NEW/RECENT indicators
- 🎨 Automatic pywal/wallust theming
- 🌍 i18n — auto-detected language (fr / en / es / ru / ja)
- ⌨️ Keyboard, scroll wheel, and gamepad navigation
- 🔍 Live search
- 📚 Library view with installation paths

## ⌨️ Controls

| Key | Action |
|-----|--------|
| `SUPER + G` | Open / Close the launcher |
| `↑ ↓ ← →` | Navigate the grid |
| `Enter` | Launch selected game |
| `Double-click` | Launch a game |
| `Esc` | Close |
| `Scroll wheel` | Navigate |
| `ALT + F` | Toggle favorite |
| `ALT + B` | Toggle Big Picture mode |

---

## 📺 Big Picture Mode

<!-- Add your screenshot here:
![Big Picture Mode](asset/Bigmode.png)
-->

Full-screen Steam Deck-style interface with:
- **Hero image** — wide banner (3840×1240 from Steam CDN, or SteamGridDB hero)
- **Stats panel** — playtime, last session, install size, last update (hidden if unavailable)
- **Game strip** — horizontal scrollable list at the bottom
- **Launch overlay** — logo + "Start Game◦◦◦" animation, launcher closes after 4 s

## 🎮 Gamepad

| Button | Action |
|--------|--------|
| ![](https://img.shields.io/badge/D--pad-grey?style=flat-square) | Navigate the grid |
| ![](https://img.shields.io/badge/A-1d7b36?style=flat-square&logo=xbox&logoColor=white) | Launch selected game |
| ![](https://img.shields.io/badge/X-1a4fa8?style=flat-square&logo=xbox&logoColor=white) | Toggle Big Picture mode |
| ![](https://img.shields.io/badge/SELECT-2c3e50?style=flat-square&logo=xbox&logoColor=white) | Toggle favorite |
| ![](https://img.shields.io/badge/B-c0392b?style=flat-square&logo=xbox&logoColor=white) | Close |

---

## 📋 Prerequisites

```bash
# Arch Linux
sudo pacman -S python qt6-declarative

# VDF library for Steam non-Steam games
pip install vdf

# Quickshell
yay -S quickshell-git
paru -S quickshell-git

# Font Awesome 7 (for icons)
yay -S ttf-font-awesome-7
paru -S ttf-font-awesome-7
```

## 🛠️ Installation

### Via AUR
```bash
paru -S quickshell-games-launchers-git
# or
yay -S quickshell-games-launchers-git
```
Run Terminal:
```bash
quickshell-game
```

### From source
```bash
git clone https://github.com/Eaquo/Quickshell-Games.git
cp -r Quickshell-Games/game-launcher ~/.config/quickshell/game-launcher
```

### Hyprland keybind

In `~/.config/hypr/hyprland.conf`:
```conf
bind = SUPER, G, exec, ~/.config/quickshell/game-launcher/toggle.sh
```
<!-- Or
```conf
bind = SUPER, G, exec, quickshell-game
``` -->

---

## ⚙️ Configuration

Everything lives in `~/.config/quickshell/game-launcher/config.toml`.

<details>
<summary><b>Display</b></summary>

```toml
[display]
position = "bottom"        # center, top, bottom
orientation = "horizontal"
grid_size = [3, 1]         # [columns, rows]
item_width = 400
item_height = 200
spacing = 20
```
</details>

<details>
<summary><b>Appearance & wallust</b></summary>

```toml
[appearance]
use_wallust = true
wallust_path = "~/.cache/wal/wal.json"
show_game_names = true
show_categories = true
show_playtime = true
blur_background = true
background_opacity = 0.85
```
</details>

<details>
<summary><b>Behavior</b></summary>

```toml
[behavior]
sort_by = "recent"           # recent, alphabetical, playtime
show_favorites_first = true
close_on_launch = true
```
</details>

<details>
<summary><b>Animations</b></summary>

```toml
[animations]
enabled = true
duration_ms = 300
ease_type = "OutCubic"
```
</details>

<details>
<summary><b>Steam</b></summary>

```toml
[steam]
enabled = true
library_paths = [
    "~/.local/share/Steam/steamapps",
    "~/.var/app/com.valvesoftware.Steam/data/Steam/steamapps",  # Flatpak
    # "/mnt/games/SteamLibrary/steamapps",                      # external drive
]
```
</details>

<details>
<summary><b>SteamGridDB</b> (optional but recommended for animated covers)</summary>

```toml
[steamgriddb]
enabled = true
api_key = "your_key_here"   # free account at steamgriddb.com

# "hero" → wide banner (1920×620) | "grid" → vertical cover (600×900) | "logo" → transparent PNG
image_type = "hero"
prefer_animated = true
sort_by_likes = true
min_likes = 0

# Performance
parallel_requests = true
max_workers = 12
request_timeout = 3        # seconds

cache_ttl_hours = 48
```
</details>

<details>
<summary><b>Heroic</b> (Epic / GOG / Amazon)</summary>

```toml
[heroic]
enabled = true
config_paths = [
    "~/.config/heroic",
    "~/.var/app/com.heroicgameslauncher.hgl/config/heroic",  # Flatpak
]
scan_epic = true
scan_gog = true
scan_amazon = true
scan_sideload = true
```
</details>

<details>
<summary><b>Filtering</b></summary>

```toml
[filtering]
games_only = false
exclude_categories = ["desktop"]
exclude_keywords = ["Launcher", "Manager", "Runtime", "SDK", "Tool"]
```
</details>

<details>
<summary><b>Manual games</b></summary>

```toml
box_art_dir = "~/.config/quickshell/game-launcher/box-art"

[[entries]]
title = "My App"
launch_command = "my-command"
path_box_art = "cover.png"   # relative to box_art_dir
```
</details>

---

## 🚀 Usage

```bash
# Launch via Quickshell
quickshell -c ~/.config/quickshell/game-launcher/shell.qml

# Or use the toggle script (recommended)
~/.config/quickshell/game-launcher/toggle.sh

# Test the backend (should output a JSON list of your games)
python3 ~/.config/quickshell/game-launcher/modules/service/backend.py

# View the full library with paths
python3 ~/.config/quickshell/game-launcher/modules/service/list_games.py
```

---

## 📁 Project Structure

```
game-launcher/
├── shell.qml                      # Quickshell entry point
├── config.toml                    # Main config
├── requirements.txt
├── toggle.sh                      # Toggle show/hide
├── modules/
│   ├── GameLauncher.qml           # Main component + grid
│   ├── GameCard.qml               # Individual game card
│   ├── BigPictureView.qml         # Big Picture fullscreen mode
│   ├── LaunchOverlay.qml          # Animated launch overlay (normal mode)
│   ├── I18n.qml                   # i18n strings (fr/en/es/ru/ja)
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

## 🎯 Technical Features

- **QML/Qt6** — Modern interface with MultiEffect for animations
- **Python 3.11+** — Backend using tomllib
- **Layer Masking** — Native rounded corners on images
- **Horizontal Carousel** — Smooth navigation with animations
- **Animated Launch Overlay** — Fullscreen card expansion on game launch
- **ACF Parsing** — Steam library path extraction
- **VDF Binary Parsing** — Non-Steam game detection via shortcuts.vdf
- **AppID Conversion** — Correct Steam AppID conversion for launching
- **JSON Parsing** — Heroic Games Launcher support
- **Gamepad Input** — Controller navigation via gamepad.py

---

## 🔧 Troubleshooting

<details>
<summary><b>Launcher doesn't open</b></summary>

```bash
quickshell -c ~/.config/quickshell/game-launcher/shell.qml
# Check for errors in the terminal
```
</details>

<details>
<summary><b>No Steam games detected</b></summary>

```bash
ls ~/.local/share/Steam/steamapps/*.acf
# Make sure the path in config.toml matches
```
</details>

<details>
<summary><b>SteamGridDB covers not loading</b></summary>

- Check that your API key is correct in config.toml
- Look at `cache/image_cache.json` to see resolved URLs
- Increase `request_timeout` if your connection is slow
</details>

<details>
<summary><b>Error `No module named 'toml'`</b></summary>

```bash
pip install toml
# or
sudo pacman -S python-toml
```
</details>

---

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest improvements
- Improve documentation

Especially useful: edge cases with Heroic or non-standard Steam libraries.

---

## 📝 License

MIT License — Free to use and modify

---

## 🙏 Credits

Inspired by [caelestia-dots/shell](https://github.com/caelestia-dots/shell)

- **[Quickshell](https://github.com/outfoxxed/quickshell)** — Qt6/QML framework for Wayland
- **[SteamGridDB](https://www.steamgriddb.com)** — Visual asset API
- **[Wallust](https://codeberg.org/explosion-mental/wallust)** — Color palette from wallpaper
- **Font Awesome** — Icons
- **Steam / Heroic** — Gaming platforms

---

<div align="center">

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/waxdred)

**Author** · Florian &nbsp;·&nbsp; **Version** · 1.2.0 &nbsp;·&nbsp; **Date** · 2026-05-21

</div>
