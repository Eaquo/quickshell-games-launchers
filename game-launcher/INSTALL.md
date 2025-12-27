# Installation rapide

## Installation automatique

Tout est déjà configuré dans `~/.config/quickshell/game-launcher/` !

### Étape 1 : Installer les dépendances

```bash
# Python TOML library
pip install --user toml

# Ou avec pipx (recommandé)
pipx install toml
```

### Étape 2 : Tester le backend

```bash
cd ~/.config/quickshell/game-launcher/
python3 backend.py
```

Vous devriez voir un JSON avec vos jeux Steam.

### Étape 3 : Ajouter le keybind Hyprland

Éditez `~/.config/hypr/hyprland.conf` et ajoutez :

```conf
# Game Launcher
bind = SUPER, G, exec, ~/.config/quickshell/game-launcher/toggle.sh
```

Rechargez Hyprland :

```bash
hyprctl reload
```

### Étape 4 : Tester

Appuyez sur `SUPER + G` pour ouvrir le launcher !

## Configuration initiale

### 1. Ajouter des jeux manuels

Éditez `~/.config/quickshell/game-launcher/games.toml` :

```toml
[[games]]
name = "Mon Jeu"
exec = "steam steam://rungameid/123456"
image = "~/Pictures/games/mon-jeu.png"
category = "rpg"
favorite = true
```

### 2. Créer le dossier pour les covers

```bash
mkdir -p ~/Pictures/games/
```

Placez-y vos images de covers (ratio 2:3 recommandé, ex: 600x900px).

### 3. Personnaliser la configuration

Éditez `~/.config/quickshell/game-launcher/config.toml` selon vos préférences.

## Vérification

### Check 1: Python

```bash
python3 --version
# Python 3.x.x
```

### Check 2: TOML

```bash
python3 -c "import toml; print('OK')"
# OK
```

### Check 3: Quickshell

```bash
quickshell --version
# quickshell x.x.x
```

### Check 4: Steam (optionnel)

```bash
ls ~/.local/share/Steam/steamapps/*.acf | wc -l
# Affiche le nombre de jeux Steam installés
```

## Dépannage rapide

### Erreur "No module named 'toml'"

```bash
pip install --user toml
```

### Le launcher ne s'affiche pas

```bash
# Test manuel
cd ~/.config/quickshell/game-launcher/
quickshell -c shell.qml
```

Regardez les erreurs dans le terminal.

### Aucun jeu Steam détecté

Vérifiez le chemin dans `config.toml` :

```bash
ls ~/.local/share/Steam/steamapps/*.acf
```

Si vide, Steam n'est pas installé ou les jeux sont ailleurs.

## Utilisation

- `SUPER + G` : Toggle launcher
- `↑↓←→` : Navigation
- `Enter` : Lancer le jeu
- `Esc` : Fermer
- `/` : Rechercher

## Prochaines étapes

1. Lisez le [README.md](README.md) complet pour toutes les fonctionnalités
2. Personnalisez `config.toml` à votre goût
3. Ajoutez vos jeux favoris dans `games.toml`
4. Créez des covers personnalisées dans `~/Pictures/games/`

Bon jeu ! 🎮
