#!/bin/bash
# Script wrapper pour lancer les modes RGB de manière détachée
SCRIPT_PATH="/home/florian/.config/quickshell/rgb-launcher/script"

MODE="$1"

if [ -z "$MODE" ]; then
    echo "Usage: $0 <mode>"
    exit 1
fi

# Tuer les anciens processus
pkill -f 'OpenRGB_Controller.py' 2>/dev/null
pkill -f 'OpenWal.py' 2>/dev/null

# Attendre un peu
sleep 0.3

# Lancer le nouveau mode de manière complètement détachée
# setsid crée une nouvelle session pour détacher le processus
setsid python3 $SCRIPT_PATH/OpenRGB_Controller.py "$MODE" </dev/null >/dev/null 2>&1 &

# Désassocier complètement du shell parent
disown

exit 0
