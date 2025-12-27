#!/bin/bash
# Test script for Game Launcher

echo "=== Game Launcher Test Suite ==="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Python
echo -n "1. Checking Python... "
if command -v python3 &> /dev/null; then
    echo -e "${GREEN}✓${NC} $(python3 --version)"
else
    echo -e "${RED}✗${NC} Python3 not found"
    exit 1
fi

# Test 2: TOML module (tomllib is built-in since Python 3.11)
echo -n "2. Checking Python TOML module... "
if python3 -c "import tomllib" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} OK (using built-in tomllib)"
else
    echo -e "${RED}✗${NC} Python 3.11+ required for tomllib"
    exit 1
fi

# Test 3: Backend
echo -n "3. Testing backend.py... "
cd "$(dirname "$0")"
if python3 backend.py > /tmp/game-launcher-test.json 2>&1; then
    GAME_COUNT=$(python3 -c "import json; data=json.load(open('/tmp/game-launcher-test.json')); print(len(data.get('games', [])))")
    echo -e "${GREEN}✓${NC} Found $GAME_COUNT games"
else
    echo -e "${RED}✗${NC} Backend failed"
    cat /tmp/game-launcher-test.json
    exit 1
fi

# Test 4: Config file
echo -n "4. Checking config.toml... "
if [ -f "config.toml" ]; then
    if python3 -c "import tomllib; tomllib.load(open('config.toml', 'rb'))" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Valid TOML"
    else
        echo -e "${RED}✗${NC} Invalid TOML syntax"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠${NC} Not found"
fi

# Test 5: Games file
echo -n "5. Checking games.toml... "
if [ -f "games.toml" ]; then
    if python3 -c "import tomllib; tomllib.load(open('games.toml', 'rb'))" 2>/dev/null; then
        MANUAL_GAMES=$(python3 -c "import tomllib; data=tomllib.load(open('games.toml', 'rb')); print(len(data.get('games', [])))")
        echo -e "${GREEN}✓${NC} $MANUAL_GAMES manual games"
    else
        echo -e "${RED}✗${NC} Invalid TOML syntax"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠${NC} Not found"
fi

# Test 6: Steam library
echo -n "6. Checking Steam library... "
STEAM_PATH="$HOME/.local/share/Steam/steamapps"
if [ -d "$STEAM_PATH" ]; then
    ACF_COUNT=$(find "$STEAM_PATH" -name "*.acf" 2>/dev/null | wc -l)
    echo -e "${GREEN}✓${NC} Found $ACF_COUNT installed games"
else
    echo -e "${YELLOW}⚠${NC} Steam not found (optional)"
fi

# Test 7: Wallust colors
echo -n "7. Checking wallust colors... "
WALLUST_PATH="$HOME/.cache/wallust/colors.json"
if [ -f "$WALLUST_PATH" ]; then
    echo -e "${GREEN}✓${NC} OK"
else
    echo -e "${YELLOW}⚠${NC} Not found (optional, will use defaults)"
fi

# Test 8: Quickshell
echo -n "8. Checking Quickshell... "
if command -v quickshell &> /dev/null; then
    echo -e "${GREEN}✓${NC} $(quickshell --version 2>&1 | head -1)"
else
    echo -e "${RED}✗${NC} Quickshell not found (install with: yay -S quickshell-git)"
fi

# Test 9: QML files
echo -n "9. Checking QML files... "
MISSING_QML=""
for file in shell.qml GameLauncher.qml GameCard.qml; do
    if [ ! -f "$file" ]; then
        MISSING_QML="$MISSING_QML $file"
    fi
done

if [ -z "$MISSING_QML" ]; then
    echo -e "${GREEN}✓${NC} All QML files present"
else
    echo -e "${RED}✗${NC} Missing:$MISSING_QML"
    exit 1
fi

# Test 10: Scripts
echo -n "10. Checking scripts... "
if [ -x "toggle.sh" ] && [ -x "backend.py" ]; then
    echo -e "${GREEN}✓${NC} Executable"
else
    echo -e "${YELLOW}⚠${NC} Not executable (run: chmod +x *.sh *.py)"
fi

echo ""
echo "=== Summary ==="
echo "Configuration directory: $(pwd)"
echo "View full backend output: cat /tmp/game-launcher-test.json"
echo ""
echo -e "${GREEN}All tests passed!${NC} You can now:"
echo "  1. Add keybind to hyprland.conf: bind = SUPER, G, exec, $(pwd)/toggle.sh"
echo "  2. Reload Hyprland: hyprctl reload"
echo "  3. Press SUPER+G to launch"
echo ""
