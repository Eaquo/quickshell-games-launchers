#!/bin/bash
# Toggle RGB Launcher

LAUNCHER_DIR="$HOME/.config/quickshell/rgb-launcher"
PID_FILE="/tmp/rgb-launcher.pid"

# Check if launcher is running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")

    # Check if process is actually running
    if ps -p "$PID" > /dev/null 2>&1; then
        # Kill the launcher
        kill "$PID"
        rm "$PID_FILE"
        exit 0
    else
        # PID file exists but process is dead, clean up
        rm "$PID_FILE"
    fi
fi

# Launch the game launcher with full path
quickshell -c "$LAUNCHER_DIR" &

# Save PID
echo $! > "$PID_FILE"
