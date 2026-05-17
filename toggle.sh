#!/bin/bash
# Game Launcher Toggle Script
# This script toggles the game launcher visibility

LAUNCHER_DIR="$HOME/.config/quickshell/game-launcher"

# Check if launcher is running via pgrep
if pgrep -f "^quickshell.*game-launcher" > /dev/null 2>&1; then
    pkill -f "^quickshell.*game-launcher"
    pkill -f "gamepad.py" 2>/dev/null || true
    exit 0
fi

# Launch the game launcher
quickshell -c "$LAUNCHER_DIR" &

