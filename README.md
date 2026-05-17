# Quickshell Game Launcher

Un launcher de jeux pour Hyprland, construit avec Quickshell (Qt6/QML) et un backend Python.
Covers animées, thème adaptatif via pywal/wallust, navigation clavier — et une petite animation de lancement qui rend le tout propre.

https://github.com/user-attachments/assets/703e48dd-86d1-49cb-8bc8-1fe45b89e9f5

![Game Launcher Preview](asset/image.png)

![Game Launcher](asset/image_2.png)

---

## Ce qui fonctionne

- Détection automatique des jeux **Steam** (parsing ACF + shortcuts.vdf pour les non-Steam)
- Support **Heroic Games Launcher** — Epic, GOG, Amazon, sideload
- Covers depuis **SteamGridDB** — heroes animées (WebP/WebM), grids, logos
- **Launch overlay** — la carte s'anime en plein écran au lancement, avec la cover animée, le logo du jeu et un indicateur "Start Game◦◦◦"
- Thème automatique via **pywal/wallust**
- Badges plateforme, favoris, indicateurs NEW/RECENT
- Navigation clavier, molette, gamepad

**Contrôles :** `←` `→` pour naviguer · `Enter` ou double-clic pour lancer · `Esc` pour fermer

---

## Installation

### Via AUR
```bash
yay -S quickshell-games-launchers-git
```

La config se copie automatiquement dans `~/.config/quickshell/game-launcher/` au premier lancement.

### Avec makepkg
```bash
git clone https://aur.archlinux.org/quickshell-games-launchers-git.git
cd quickshell-games-launchers-git
makepkg -si
```

### Depuis les sources
```bash
git clone https://github.com/Eaquo/Quickshell-Games.git
cp -r Quickshell-Games/game-launcher ~/.config/quickshell/game-launcher
```

### Dépendances
```bash
# Arch
sudo pacman -S python qt6-declarative

# Parsing Steam non-Steam games
pip install vdf

# Quickshell
yay -S quickshell-git

# Icônes
yay -S ttf-font-awesome-7
```

---

## Configuration

Tout se passe dans `~/.config/quickshell/game-launcher/config.toml`.

**Steam :**
```toml
[steam]
enabled = true
library_paths = [
  "~/.local/share/Steam/steamapps",
  # "/mnt/games/Steam/steamapps",  # disque externe
]
```

**Heroic :**
```toml
[heroic]
enabled = true
config_paths = ["~/.config/heroic"]
scan_epic = true
scan_gog = true
scan_amazon = true
scan_sideload = true
```

**SteamGridDB** (optionnel mais recommandé pour les covers animées) :
```toml
[steamgriddb]
enabled = true
api_key = "ta_clé_ici"   # compte gratuit sur steamgriddb.com
image_type = "hero"       # hero, grid, logo
prefer_animated = true
sort_by_likes = true
cache_ttl_hours = 48
```

**Jeux manuels** :
```toml
[[entries]]
title = "Mon app"
launch_command = "nom-de-la-commande"
path_box_art = "cover.png"   # dans box-art/
```

---

## Structure
```
game-launcher/
├── modules/
│   ├── GameLauncher.qml      # Composant principal + grille
│   ├── GameCard.qml          # Carte individuelle
│   ├── LaunchOverlay.qml     # Overlay de lancement animé
│   └── service/
│       ├── backend.py        # Scanner Steam/Heroic/manuel + SteamGridDB
│       ├── gamepad.py        # Support manette
│       ├── list_games.py     # Affichage bibliothèque
│       └── py_vdf_list.py
├── box-art/                  # Covers manuelles
├── cache/                    # Cache images SteamGridDB
├── config.toml
├── requirements.txt
├── shell.qml
└── toggle.sh
```

---

## Stack

- **QML/Qt6** avec MultiEffect pour l'interface et les animations
- **Python 3.11+** avec tomllib pour le backend
- Parsing **ACF** et **VDF binaire** pour Steam
- Support **JSON** pour Heroic

---

## Contribuer

Issues, PRs, retours d'expérience — tout est bienvenu.
Notamment si tu croises des cas particuliers avec Heroic ou des bibliothèques Steam non-standard.

---

## Licence

MIT

---

## Support

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/waxdred)

---

Merci à **Quickshell**, **pywal/wallust**, **Font Awesome**, Steam et Heroic.