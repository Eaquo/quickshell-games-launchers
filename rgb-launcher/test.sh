#!/bin/bash
# Test RGB Launcher

LAUNCHER_DIR="$HOME/.config/quickshell/rgb-launcher"

echo "Testing RGB Launcher..."
echo ""

# Test Python backend
echo "1. Testing Python backend..."
cd "$LAUNCHER_DIR" || exit 1

if ! python3 backend.py > /dev/null 2>&1; then
    echo "❌ Backend failed"
    echo ""
    echo "Running backend to see errors:"
    python3 backend.py
    exit 1
else
    echo "✅ Backend working"
fi

echo ""

# Show loaded modes
echo "2. Loaded RGB modes:"
python3 backend.py | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    modes = data.get('modes', [])
    print(f'   Found {len(modes)} modes:')
    for mode in modes:
        print(f'   - {mode[\"icon\"]} {mode[\"name\"]} ({mode[\"category\"]})')

    colors = data.get('colors', {})
    print(f'\\n   Colors loaded: {\"background\" in colors}')
    print(f'   Brightness: {data.get(\"brightness\", \"N/A\")}%')
except Exception as e:
    print(f'   Error: {e}')
"

echo ""
echo "3. Testing Quickshell launch..."
echo "   Launching in 2 seconds (Ctrl+C to cancel)..."
sleep 2

quickshell -c "$LAUNCHER_DIR"
