# Game Launcher pour Hyprland

Un launcher de jeux moderne et stylisé pour Hyprland, construit avec Quickshell (Qt6/QML).

![Game Launcher](https://via.placeholder.com/800x600?text=Game+Launcher+Preview)

![Game Preview](game-launcher/image_2.png)

## Fonctionnalités

- **Détection automatique des jeux Steam** depuis votre bibliothèque
- **Jeux manuels** via fichier TOML
- **Interface moderne** avec grille personnalisable
- **Navigation clavier** complète (flèches, Enter, Escape)
- **Recherche en temps réel** avec filtrage
- **Intégration wallust** pour thème adaptatif
- **Animations fluides** et effets visuels
- **Favoris** et catégories
- **Covers Steam automatiques**

## Structure du projet

```
~/.config/quickshell/game-launcher/
├── shell.qml              # Point d'entrée Quickshell
├── GameLauncher.qml       # Composant principal
├── GameCard.qml           # Carte de jeu individuelle
├── backend.py             # Backend Python (scan Steam + TOML)
├── config.toml            # Configuration principale
├── games.toml             # Jeux manuels
├── toggle.sh              # Script de toggle
├── requirements.txt       # Dépendances Python
└── README.md              # Cette documentation
```

## Installation

### 1. Dépendances

```bash
# Quickshell (si pas déjà installé)
yay -S quickshell-git

# Python et dépendances
sudo pacman -S python python-pip
pip install -r ~/.config/quickshell/game-launcher/requirements.txt

# Optionnel : wallust pour les thèmes
yay -S wallust
```

### 2. Vérification de l'installation

Les fichiers sont déjà créés dans `~/.config/quickshell/game-launcher/`.

Vérifiez que le backend fonctionne :

```bash
cd ~/.config/quickshell/game-launcher/
python3 backend.py
```

Vous devriez voir un JSON avec vos jeux Steam et la configuration.

### 3. Configuration Hyprland

Ajoutez un keybind dans votre `~/.config/hypr/hyprland.conf` :

```conf
# Game Launcher Toggle
bind = SUPER, G, exec, ~/.config/quickshell/game-launcher/toggle.sh
```

Rechargez Hyprland :

```bash
hyprctl reload
```

## Configuration

### config.toml

Le fichier principal de configuration :

```toml
Important compte SteamGridDB pour clef api
api_key = ""


[display]
position = "center"      # center, top, bottom, left, right
grid_size = [4, 3]       # [colonnes, lignes]
item_width = 220
item_height = 300
spacing = 20

[steam]
enabled = true
library_paths = [
    "~/.local/share/Steam/steamapps",
]
fetch_covers = true

[appearance]
use_wallust = true
wallust_path = "~/.cache/wallust/colors.json"
show_game_names = true
show_categories = true
show_playtime = true
blur_background = true
background_opacity = 0.85

[behavior]
sort_by = "recent"              # recent, name, playtime, favorite
show_favorites_first = true
close_on_launch = true

[animations]
enabled = true
duration_ms = 300
ease_type = "OutCubic"
```

### games.toml

Ajoutez vos jeux personnalisés :

```toml
[[games]]
name = "Elden Ring"
exec = "gamescope -W 3440 -H 1440 -f -- steam steam://rungameid/1245620"
image = "~/Pictures/games/elden-ring.png"
category = "souls-like"
favorite = true

[[games]]
name = "Mon Jeu Indie"
exec = "/usr/bin/mon-jeu"
image = "~/Pictures/games/indie.png"
category = "indie"
favorite = false
```

## Utilisation

### Raccourcis clavier

| Touche | Action |
|--------|--------|
| `SUPER + G` | Ouvrir/Fermer le launcher |
| `↑ ↓ ← →` | Navigation dans la grille |
| `Enter` | Lancer le jeu sélectionné |
| `Escape` | Fermer le launcher |
| `/` ou `F` | Focus sur la recherche |
| `Double-clic` | Lancer un jeu |

### Recherche

Appuyez sur `/` ou `F` pour rechercher :
- Par nom de jeu
- Par catégorie

### Favoris

Dans `games.toml`, marquez un jeu comme favori :

```toml
[[games]]
name = "Mon Jeu Préféré"
favorite = true
```

Les favoris apparaissent en premier (si `show_favorites_first = true`).

## Personnalisation

### Changer la position

Dans `config.toml` :

```toml
[display]
position = "center"  # Changez en: top, bottom, left, right
```

### Ajuster la grille

```toml
[display]
grid_size = [5, 2]  # 5 colonnes, 2 lignes
```

### Désactiver les animations

```toml
[animations]
enabled = false
```

### Utiliser sans wallust

```toml
[appearance]
use_wallust = false
```

Le launcher utilisera des couleurs par défaut.

### Covers personnalisées

Pour les jeux Steam, les covers sont automatiquement téléchargées depuis le CDN Steam.

Pour les jeux manuels, placez vos images dans `~/Pictures/games/` :

```toml
[[games]]
name = "Mon Jeu"
image = "~/Pictures/games/mon-jeu.png"  # Format PNG ou JPG
```

Ratio recommandé : **2:3** (ex: 600x900px)

## Intégration Steam

### Détection automatique

Le backend scanne automatiquement :
- `~/.local/share/Steam/steamapps/*.acf`

### Ajouter d'autres bibliothèques Steam

Si vous avez des jeux Steam sur d'autres disques :

```toml
[steam]
library_paths = [
    "~/.local/share/Steam/steamapps",
    "/mnt/games/SteamLibrary/steamapps",
]
```

### Lancer avec gamescope

Pour un jeu Steam avec gamescope personnalisé :

```toml
[[games]]
name = "Elden Ring"
exec = "gamescope -W 2560 -H 1440 -f -r 144 -- steam steam://rungameid/1245620"
category = "souls-like"
favorite = true
```

## Intégration Wallust

Le launcher s'adapte automatiquement aux couleurs de votre wallpaper via wallust.

### Générer les couleurs

```bash
wallust run ~/Pictures/wallpapers/current.png
```

Le launcher lira automatiquement `~/.cache/wallust/colors.json`.

### Schéma de couleurs utilisé

- `background` : Fond du launcher et cartes
- `foreground` : Texte principal
- `color1` : Barre de recherche
- `color2` : Badges de catégories
- `color3` : Étoile des favoris
- `color5` : Bordures et accents (cyan par défaut)

## Dépannage

### Le launcher ne s'affiche pas

1. Vérifiez que Quickshell est installé :
   ```bash
   quickshell --version
   ```

2. Testez le backend :
   ```bash
   cd ~/.config/quickshell/game-launcher/
   python3 backend.py
   ```

3. Vérifiez les logs Quickshell :
   ```bash
   quickshell -c ~/.config/quickshell/game-launcher/shell.qml
   ```

### Pas de jeux Steam détectés

1. Vérifiez que Steam est installé :
   ```bash
   ls ~/.local/share/Steam/steamapps/*.acf
   ```

2. Vérifiez le chemin dans `config.toml` :
   ```toml
   [steam]
   library_paths = ["~/.local/share/Steam/steamapps"]
   ```

### Les covers ne s'affichent pas

Les covers Steam sont téléchargées depuis :
```
https://cdn.cloudflare.steamstatic.com/steam/apps/{APPID}/library_600x900.jpg
```

Vérifiez votre connexion internet. Si une cover n'existe pas, un placeholder avec initiales s'affiche.

### Erreur Python "No module named 'toml'"

Installez la dépendance :
```bash
pip install toml
```

### Le script toggle.sh ne fonctionne pas

Vérifiez les permissions :
```bash
chmod +x ~/.config/quickshell/game-launcher/toggle.sh
```

## Architecture technique

### Backend Python (`backend.py`)

- Scanne les fichiers `.acf` Steam pour détecter les jeux
- Parse les fichiers TOML (config + jeux manuels)
- Génère un JSON avec toutes les données
- Gère le tri et le filtrage
- Intégration wallust

### Frontend QML

**`shell.qml`**
- Point d'entrée Quickshell
- Gestion de la fenêtre overlay
- Gestion de la visibilité

**`GameLauncher.qml`**
- Composant principal
- Grille de jeux avec GridView
- Barre de recherche et filtrage
- Navigation clavier
- Communication avec le backend Python

**`GameCard.qml`**
- Carte individuelle pour chaque jeu
- Cover, nom, catégorie, favori
- Effets hover et sélection
- Ombres et animations

### Communication

```
Python (backend.py) → JSON → QML (Process)
                            ↓
                         GameLauncher
                            ↓
                    [Game, Game, Game...]
```

## Roadmap / Améliorations futures

- [ ] Support Epic Games Store
- [ ] Support Lutris
- [ ] Statistiques de temps de jeu (Steam API)
- [ ] Tri par popularité
- [ ] Thèmes personnalisés (sans wallust)
- [ ] Export/Import de configurations
- [ ] Multi-écrans
- [ ] Grid layout alternatif (liste)
- [ ] Raccourcis personnalisables

## Contribution

Ce projet est open-source. N'hésitez pas à :
- Signaler des bugs
- Proposer des améliorations
- Ajouter des fonctionnalités

## Licence

MIT License

## Crédits

Inspiré par [caelestia-dots/shell](https://github.com/caelestia-dots/shell)

Construit avec :
- [Quickshell](https://github.com/outfoxxed/quickshell) - Qt6/QML pour Wayland
- [Wallust](https://codeberg.org/explosion-mental/wallust) - Générateur de colorschemes
- Python 3 + TOML

---

**Profitez de votre collection de jeux !** 🎮
