# 💡 RGB Launcher pour Quickshell

Launcher moderne pour contrôler OpenRGB avec Quickshell (Qt6/QML) pour Hyprland.

## ✨ Fonctionnalités

- **Carousel horizontal** - Naviguez entre les modes RGB avec les flèches ← →
- **Modes RGB multiples** - Pywal Sync, Rainbow, Breathing, Static, Cycle, OFF
- **Slider de luminosité** - Ajustez la luminosité RGB de 0% à 100%
- **Intégration pywal** - Les couleurs s'adaptent à votre wallpaper
- **Animations fluides** - Effets de glow et breathing sur la carte sélectionnée
- **Navigation clavier & souris** - Flèches, molette, Enter, Esc

## 📦 Structure

```
rgb-launcher/
├── backend.py           # Backend Python pour charger les modes
├── config.toml          # Configuration des modes RGB
├── shell.qml            # Point d'entrée Quickshell
├── RGBLauncher.qml      # Composant principal avec carousel
├── ModeCard.qml         # Carte individuelle pour chaque mode
├── toggle.sh            # Script pour ouvrir/fermer le launcher
├── test.sh              # Script de test
└── README.md            # Ce fichier
```

## 🚀 Utilisation

### Lancer le RGB Launcher

```bash
# Option 1: Via Quickshell directement
quickshell -c ~/.config/quickshell/rgb-launcher

# Option 2: Via le script toggle
~/.config/quickshell/rgb-launcher/toggle.sh

# Option 3: Ajouter un keybind Hyprland
bind = $mainMod SHIFT, R, exec, ~/.config/quickshell/rgb-launcher/toggle.sh
```

### Navigation

- **← →** - Naviguer entre les modes RGB
- **Molette haut/bas** - Naviguer entre les modes
- **Enter / Espace** - Activer le mode sélectionné
- **Esc / Q** - Fermer le launcher
- **Slider** - Ajuster la luminosité RGB

## ⚙️ Configuration

### Fichier `config.toml`

```toml
[display]
position = "center"
item_width = 280
item_height = 320
spacing = 20

[openrgb]
controller_path = "/home/florian/.config/hypr/Openrgb/OpenRGB_Controller.py"
brightness_script = "/home/florian/.config/hypr/Openrgb/apply_brightness.py"

[appearance]
use_pywal = true
pywal_path = "~/.cache/wal/wal.json"

[[modes]]
name = "Pywal Sync"
description = "Synchronise RGB avec les couleurs du wallpaper"
command = "python3 /home/florian/.config/hypr/Openrgb/OpenWal.py"
icon = "🎨"
color_preview = "gradient"
category = "dynamic"
```

### Ajouter un nouveau mode RGB

Ajoutez un nouveau bloc `[[modes]]` dans `config.toml`:

```toml
[[modes]]
name = "Mon Mode Custom"
description = "Description de mon mode"
command = "python3 /path/to/script.py --mode custom"
icon = "✨"
color_preview = "static"  # static, gradient, rainbow, pulse, cycle, off
category = "animation"     # dynamic, animation, static, control
```

### Types de preview disponibles

- `static` - Couleur fixe (color5 de pywal)
- `gradient` - Dégradé des couleurs pywal (color4, color5, color6)
- `rainbow` - Dégradé arc-en-ciel rotatif
- `pulse` - Effet de pulsation
- `cycle` - Cycle de couleurs
- `off` - Noir (pour le mode OFF)

## 🎨 Couleurs pywal

Le launcher charge automatiquement les couleurs depuis `~/.cache/wal/wal.json`:
- Background, foreground, cursor
- color0 à color15

Pour changer le chemin:
```toml
[appearance]
pywal_path = "~/.cache/wallust/colors.json"  # ou autre chemin
```

## 🔧 Dépendances

- **Quickshell** - Framework Qt6/QML pour Wayland
- **Python 3.11+** - Pour le backend (avec tomllib intégré)
- **OpenRGB** - Contrôle des LEDs RGB
- **pywal** - Génération de couleurs (optionnel)

## 🧪 Test

```bash
# Tester le backend Python
cd ~/.config/quickshell/rgb-launcher
python3 backend.py

# Tester le launcher complet
./test.sh
```

## 📝 Notes

- Le fichier de luminosité est sauvegardé dans `/home/florian/.config/hypr/Openrgb/brightness.txt`
- Les modes RGB sont exécutés en arrière-plan via `Process`
- Le launcher ne se ferme pas automatiquement après sélection (configurable avec `close_on_select`)

## 🔗 Intégration avec OpenRGB

Assurez-vous que vos scripts OpenRGB acceptent les arguments:

```python
# OpenRGB_Controller.py
import sys
if "--mode" in sys.argv:
    mode = sys.argv[sys.argv.index("--mode") + 1]
    # Appliquer le mode
```

## 🎮 Projet similaire

Ce launcher est basé sur le même principe que le [Game Launcher](../game-launcher/README.md).
