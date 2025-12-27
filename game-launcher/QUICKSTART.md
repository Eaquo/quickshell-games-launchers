# 🎮 Quick Start - Game Launcher

## Installation en 3 étapes

### 1️⃣ Installer les dépendances

```bash
pip install --user toml
```

### 2️⃣ Tester que tout fonctionne

```bash
cd ~/.config/quickshell/game-launcher/
./test.sh
```

Ce script va vérifier :
- Python et TOML
- Les jeux Steam détectés
- Les fichiers de configuration
- Quickshell
- Tous les composants QML

### 3️⃣ Configurer le keybind Hyprland

Ajoutez à `~/.config/hypr/hyprland.conf` :

```conf
bind = SUPER, G, exec, ~/.config/quickshell/game-launcher/toggle.sh
```

Puis rechargez :

```bash
hyprctl reload
```

## ✅ C'est tout !

Appuyez sur **SUPER + G** pour ouvrir le launcher.

## 🎯 Prochaines étapes

### Personnaliser les jeux

Éditez [games.toml](games.toml) :

```toml
[[games]]
name = "Mon Jeu Préféré"
exec = "steam steam://rungameid/123456"
image = "~/Pictures/games/cover.png"
category = "rpg"
favorite = true
```

### Personnaliser l'apparence

Éditez [config.toml](config.toml) :

```toml
[display]
grid_size = [5, 2]    # Plus de colonnes, moins de lignes
item_width = 200      # Cartes plus petites

[appearance]
background_opacity = 0.9  # Plus opaque
```

### Créer des covers

```bash
mkdir -p ~/Pictures/games/
```

Ajoutez vos images (ratio 2:3, ex: 600x900px).

## 📚 Documentation complète

- [README.md](README.md) - Documentation détaillée
- [INSTALL.md](INSTALL.md) - Guide d'installation
- [hyprland-example.conf](hyprland-example.conf) - Exemples de config Hyprland

## 🐛 Problème ?

Lancez le test :

```bash
./test.sh
```

Ou testez manuellement :

```bash
# Test backend
python3 backend.py

# Test Quickshell
quickshell -c shell.qml
```

## 🎮 Utilisation

| Raccourci | Action |
|-----------|--------|
| `SUPER + G` | Ouvrir/Fermer |
| `↑ ↓ ← →` | Naviguer |
| `Enter` | Lancer le jeu |
| `Esc` | Fermer |
| `/` ou `F` | Rechercher |

## 💡 Astuces

1. **Double-clic** sur une carte pour lancer immédiatement
2. **Recherche** : tapez le nom ou la catégorie
3. **Favoris** : marqués avec ⭐, apparaissent en premier
4. **Wallust** : le launcher s'adapte à vos couleurs wallpaper
5. **Catégories** : créez vos propres tags pour organiser

---

**Bon jeu !** 🚀
