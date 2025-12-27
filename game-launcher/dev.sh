#!/bin/bash
# Development mode - Auto-reload on file changes

LAUNCHER_DIR="$HOME/.config/quickshell/game-launcher"
PID_FILE="/tmp/quickshell-game-launcher-dev.pid"

echo "🔥 Game Launcher - Mode développement"
echo "Surveillance des fichiers: *.qml, *.py, *.toml"
echo "Appuyez sur Ctrl+C pour arrêter"
echo ""

# Fonction pour lancer quickshell
launch_quickshell() {
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            echo "⏹️  Arrêt de l'instance précédente (PID: $OLD_PID)"
            kill "$OLD_PID" 2>/dev/null
            sleep 0.5
        fi
    fi

    echo "🚀 Lancement de Quickshell..."
    quickshell -c "$LAUNCHER_DIR" > /tmp/quickshell-dev.log 2>&1 &
    echo $! > "$PID_FILE"
    echo "✅ Quickshell lancé (PID: $!)"
    echo ""
}

# Fonction de nettoyage
cleanup() {
    echo ""
    echo "🛑 Arrêt du mode développement..."
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            kill "$PID" 2>/dev/null
        fi
        rm "$PID_FILE"
    fi
    exit 0
}

trap cleanup INT TERM

# Vérifier si inotify-tools est installé
if ! command -v inotifywait &> /dev/null; then
    echo "⚠️  inotify-tools n'est pas installé"
    echo "Installation: sudo pacman -S inotify-tools"
    echo ""
    echo "Mode fallback: relancement manuel avec 'r'"

    launch_quickshell

    while true; do
        read -n 1 -s key
        if [ "$key" = "r" ]; then
            echo "🔄 Rechargement manuel..."
            launch_quickshell
        elif [ "$key" = "q" ]; then
            cleanup
        fi
    done
fi

# Lancer une première fois
launch_quickshell

# Surveiller les changements de fichiers
cd "$LAUNCHER_DIR"
while true; do
    inotifywait -q -e modify,create,delete \
        --include '.*\.(qml|py|toml)$' \
        -r . 2>/dev/null

    echo "📝 Modification détectée - Rechargement..."
    sleep 0.3  # Petit délai pour éviter les recharges multiples
    launch_quickshell
done
