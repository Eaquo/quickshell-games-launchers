# Quickshell Launchers
Collection of Quickshell launchers for Hyprland with pywal/wallust integration.

![Game Launcher Preview](__game-launcher/Readme/asset/image.png__)

## 📦 Projects

### 🎮 Game Launcher

Game launcher with multi-platform support and a sleek interface.

![Game Launcher Preview](__game-launcher/Readme/asset/image_2.png__)

**Features:**
- 🎯 Support for Steam, non-Steam games, Heroic (Epic/GOG/Amazon), and manual entries
- 🎮 Automatic detection of non-Steam games added to Steam (via shortcuts.vdf)
- 🖼️ Automatic cover art from Steam/SteamGridDB
- 🏷️ Platform badges and categories
- ⭐ Favorites system
- 🆕 NEW/RECENT indicators
- 🎨 Automatic pywal/wallust theming
- ⌨️ Keyboard and scroll wheel navigation
- 📚 Library view with installation paths

**Controls:**
- `←` `→` : Navigate
- `Enter` : Launch game
- `Double-click` : Launch game
- `Esc` : Close
- `Scroll wheel` : Navigate

## 🛠️ Installation

### Prerequisites

```bash
# Arch Linux
sudo pacman -S python qt6-declarative

# VDF library for Steam (non-Steam games)
pip install vdf

# Quickshell
yay -S quickshell-git

# Font Awesome 7 (for icons)
yay -S ttf-font-awesome-7
```

### Configuration

#### Game Launcher

1. **Configure Steam:**

```toml
# game-launcher/config.toml
[steam]
enabled = true
library_paths = [
  "~/.local/share/Steam/steamapps",
  "/mnt/games/Steam/steamapps",  # Add your paths
]

# Optional SteamGridDB API key
api_key = ""
```

2. **Configure Heroic:**

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

3. **Add manual games:**

```toml
# game-launcher/games.toml
[[entries]]
title = "📚 Game Library"
launch_command = "kitty -e python3 /home/florian/.config/quickshell/game-launcher/module/service/list_games.py"
path_box_art = "library.png"
```

4. **Create the box-art folder:**

```bash
mkdir -p ~/.config/quickshell/game-launcher/box-art
```

## 🚀 Usage

### Game Launcher

```bash
# Launch from Quickshell
quickshell game-launcher/GameLauncher.qml

# View the full library
python3 game-launcher/list_games.py
```

## 📁 Project Structure

```
quickshell/
├── game-launcher/
│   └── box-art/                    # Manual game covers
│   └── modules/                    # Components and scripts
│       ├── GameCard.qml            # Game card component
│       ├── GameLauncher.qml        # Main interface
│       └── service/                # Scripts
│           ├── backend.py          # Steam/Heroic/manual game scanner
│           └── list_games.py       # Displays library + paths
└── Readme/                         # Readme
│   └── asset/
│   └── README.md
│   config.toml
│   shell.qml
└   toggle.sh
```

## 🎯 Technical Features

### Game Launcher

- **QML/Qt6** — Modern interface with MultiEffect
- **Python 3.11+** — Backend using tomllib
- **Layer Masking** — Native rounded corners on images
- **Horizontal Carousel** — Smooth navigation with animations
- **ACF Parsing** — Steam path extraction
- **VDF Binary Parsing** — Non-Steam game detection via shortcuts.vdf
- **AppID Conversion** — Correct Steam AppID conversion for launching
- **JSON Parsing** — Heroic Games Launcher support

## 🤝 Contributing

Contributions are welcome! Feel free to:

- Report bugs
- Suggest improvements
- Add RGB sequences
- Improve documentation

## 📝 License

MIT License — Free to use and modify

## 🙏 Credits

- **Quickshell** — QML framework for Wayland
- **pywal/wallust** — Color palette generation
- **Font Awesome** — Icons
- **Steam/Heroic** — Gaming platforms

---

**Author:** Florian  
**Version:** 1.0.1  
**Date:** 2026
