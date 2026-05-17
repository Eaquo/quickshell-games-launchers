#!/bin/bash
# Run a command in the user's default terminal
# Detects terminal from $TERMINAL env or common terminals

detect_terminal() {
    if [[ -n "$TERMINAL" ]]; then
        echo "$TERMINAL"
        return 0
    fi

    for term in kitty alacritty foot wezterm gnome-terminal konsole xterm \
                xfce4-terminal terminator tilix lxterminal sakura urxvt st \
                mate-terminal pantheon-terminal deepin-terminal guake tilda \
                yakuake cool-retro-term; do
        if command -v "$term" &>/dev/null; then
            echo "$term"
            return 0
        fi
    done

    return 1
}

cmd="$*"

if [[ -z "$cmd" ]]; then
    echo "Usage: $0 <command>"
    exit 1
fi

term=$(detect_terminal)

if [[ -n "$term" ]]; then
    case "$term" in
        gnome-terminal)
            "$term" -- "$SHELL" -c "$cmd"
            ;;
        yakuake)
            qdbus org.kde.yakuake /yakuake/window org.kde.yakuake.toggleWindow 2>/dev/null || true
            "$term" -e "$SHELL" -c "$cmd"
            ;;
        guake)
            guake --show 2>/dev/null || true
            "$term" -e "$SHELL" -c "$cmd"
            ;;
        *)
            "$term" -e "$SHELL" -c "$cmd"
            ;;
    esac
else
    echo "Error: No terminal found. Please set \$TERMINAL or install a terminal." >&2
    notify-send -u critical "Game Launcher" "No terminal found. Please set \$TERMINAL or install a terminal." 2>/dev/null || true
    exit 1
fi