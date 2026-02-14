#!/usr/bin/env python3
"""
Game Launcher Backend
Scans Steam library and custom games, outputs JSON for QML
"""

import json
import os
import sys
import tomllib
from pathlib import Path
from typing import List, Dict, Any
import re
import urllib.request
import urllib.error
import struct
import binascii
import vdf


class GameLauncher:
    def __init__(self, config_path: str = None):
        if config_path is None:
            config_path = Path.home() / ".config/quickshell/game-launcher/config.toml"

        self.config_path = Path(config_path)
        self.config = self.load_config()
        self.games = []

    def load_config(self) -> Dict[str, Any]:
        """Load configuration from TOML file"""
        try:
            with open(self.config_path, 'rb') as f:
                return tomllib.load(f)
        except FileNotFoundError:
            print(f"Config file not found: {self.config_path}", file=sys.stderr)
            return self.get_default_config()
        except Exception as e:
            print(f"Error loading config: {e}", file=sys.stderr)
            return self.get_default_config()

    def get_default_config(self) -> Dict[str, Any]:
        """Return default configuration"""
        return {
            "steam": {
                "enabled": True,
                "library_paths": ["~/.local/share/Steam/steamapps"],
                "fetch_covers": True
            },
            "heroic": {
                "enabled": True,
                "config_paths": ["~/.config/heroic"],
                "scan_epic": True,
                "scan_gog": True,
                "scan_amazon": True,
                "scan_sideload": True
            },
            "lutris": {
                "enabled": True,
                "config_path": "~/.config/lutris"
            },
            "behavior": {
                "sort_by": "recent",
                "show_favorites_first": True
            }
        }

    def expand_path(self, path: str) -> Path:
        """Expand ~ and environment variables in path"""
        return Path(os.path.expanduser(os.path.expandvars(path)))

    def scan_steam_library(self) -> List[Dict[str, Any]]:
        """Scan Steam library for installed games"""
        games = []

        if not self.config.get("steam", {}).get("enabled", True):
            return games

        library_paths = self.config.get("steam", {}).get("library_paths", [])

        for lib_path in library_paths:
            lib_path = self.expand_path(lib_path)

            if not lib_path.exists():
                print(f"Steam library path not found: {lib_path}", file=sys.stderr)
                continue

            # Scan for .acf files (Steam app manifests)
            for acf_file in lib_path.glob("*.acf"):
                game_data = self.parse_acf_file(acf_file)
                if game_data:
                    games.append(game_data)

        return games

    def is_steam_tool(self, name: str) -> bool:
        """Check if a Steam app is a tool/runtime (not a game)"""
        tool_patterns = [
            "proton",
            "steam linux runtime",
            "steamworks common",
            "steam runtime",
            "redistributable",
            "sdk",
            "dedicated server",
            "tool",
            "hotfix",
            "steamvr",
            "steam audio",
            "steam shader",
            "steam workshop",
            "steam controller",
            "directx",
            "vcredist",
            "visual c++",
            ".net framework",
            "microsoft visual",
            "steam play",
            "compatibility tool"
        ]

        name_lower = name.lower()
        return any(pattern in name_lower for pattern in tool_patterns)

    def parse_acf_file(self, acf_path: Path) -> Dict[str, Any]:
        """Parse Steam .acf manifest file"""
        try:
            with open(acf_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()

            # Extract app ID
            app_id_match = re.search(r'"appid"\s+"(\d+)"', content)
            if not app_id_match:
                return None
            app_id = app_id_match.group(1)

            # Extract game name
            name_match = re.search(r'"name"\s+"([^"]+)"', content)
            if not name_match:
                return None
            name = name_match.group(1)

            # Filter out Steam tools (Proton, Runtime, etc.)
            if self.is_steam_tool(name):
                return None

            # Extract install directory
            install_dir_match = re.search(r'"installdir"\s+"([^"]+)"', content)
            install_dir = install_dir_match.group(1) if install_dir_match else ""

            # Extract last played time (Unix timestamp)
            last_played_match = re.search(r'"LastPlayed"\s+"(\d+)"', content)
            last_played = int(last_played_match.group(1)) if last_played_match else 0

            # Get cover image
            cover_url = self.get_steam_cover_url(app_id)

            return {
                "name": name,
                "exec": f"steam steam://rungameid/{app_id}",
                "image": cover_url,
                "category": "steam",
                "favorite": False,
                "appid": app_id,
                "last_played": last_played,
                "source": "steam"
            }

        except Exception as e:
            print(f"Error parsing {acf_path}: {e}", file=sys.stderr)
            return None

    def get_steam_cover_url(self, app_id: str) -> str:
        """Get Steam grid/cover image URL with fallbacks"""
        # Primary: header.jpg (horizontal banner)
        # Fallback 1: library_600x900.jpg (vertical portrait)
        # Fallback 2: capsule_616x353.jpg

        # Return list of possible URLs (QML will try them in order)
        base_url = f"https://cdn.cloudflare.steamstatic.com/steam/apps/{app_id}"

        # For now, return primary header format
        # TODO: Implement image validation and fallback in QML or backend
        return f"{base_url}/header.jpg"

    def convert_appid_to_long(self, appid: int) -> int:
        """
        Convert short AppID (from shortcuts.vdf) to long AppID (for steam://rungameid/)
        Method from @bkbilly on GitHub
        """
        # Convert to HEX int32
        int32 = struct.Struct('<i')
        bin_appid = int32.pack(appid)
        hex_appid = binascii.hexlify(bin_appid).decode()

        # Convert to long_appid
        reversed_hex = bytes.fromhex(hex_appid)[::-1].hex()
        long_appid = int(reversed_hex, 16) << 32 | 0x02000000

        return long_appid

    def parse_vdf_shortcuts(self, file_path: Path) -> List[Dict[str, Any]]:
        """Parse Steam shortcuts.vdf (binary VDF format) using vdf library"""
        games = []

        try:
            with open(file_path, 'rb') as f:
                shortcuts_data = vdf.binary_load(f)

            # shortcuts_data = {'shortcuts': {'0': {...}, '1': {...}, ...}}
            for idx, app in shortcuts_data.get('shortcuts', {}).items():
                game_data = self.process_shortcut_entry(app)
                if game_data:
                    games.append(game_data)

        except Exception as e:
            print(f"Error parsing shortcuts.vdf {file_path}: {e}", file=sys.stderr)

        return games

    def process_shortcut_entry(self, app: Dict[str, Any]) -> Dict[str, Any]:
        """Parse a single shortcut entry from VDF binary data
        Returns: (shortcut_dict, end_position)
        """
        # Extract fields from the parsed shortcut
        name = app.get('AppName', app.get('appname', 'Unknown'))
        exe = app.get('Exe', app.get('exe', ''))
        icon = app.get('icon', '')
        short_appid = app.get('appid', 0)

        # Skip if no name
        if not name or name == 'Unknown':
            return None

        try:
            # Skip games with invalid/inaccessible executables (e.g., Windows paths on Linux)
            if exe:
                # Clean up exe path (remove quotes)
                exe_clean = exe.strip('"').strip("'")

                # Check if it's a Windows path (C:\, D:\, etc.)
                is_windows_path = len(exe_clean) > 2 and exe_clean[1:3] == ':\\'

                # Skip if it's a Windows path (invalid on Linux)
                if is_windows_path:
                    return None

                # For Linux paths, check if executable exists
                expanded_path = os.path.expanduser(exe_clean)
                if not os.path.exists(expanded_path) and not exe_clean.startswith('steam://'):
                    # Skip if file doesn't exist and it's not a Steam URI
                    return None

            # Convert short AppID to long AppID for steam:// URI
            long_appid = self.convert_appid_to_long(short_appid) if short_appid else 0

            # Determine category based on game type
            exe_clean = exe.strip('"').strip("'") if exe else ""
            if "PortProton" in exe or "portproton" in exe.lower():
                category = "steam_proton"
            else:
                category = "steam_app_0"

            # Use Steam URI to launch non-Steam games through Steam
            exec_cmd = f"steam steam://rungameid/{long_appid}"

            return {
                "name": name,
                "exec": exec_cmd,
                "image": icon if icon and os.path.exists(os.path.expanduser(icon)) else "",
                "category": category,
                "favorite": False,
                "appid": str(long_appid),
                "last_played": app.get('LastPlayTime', 0),
                "source": "steam-shortcuts"
            }

        except Exception as e:
            print(f"Error processing shortcut: {e}", file=sys.stderr)
            return None

    def parse_desktop_file(self, desktop_path: Path) -> Dict[str, Any]:
        """Parse a .desktop file and extract game information"""
        try:
            with open(desktop_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Extract Name
            name_match = re.search(r'^Name=(.+)$', content, re.MULTILINE)
            name = name_match.group(1) if name_match else desktop_path.stem

            # Extract Exec for category detection
            exec_match = re.search(r'^Exec=(.+)$', content, re.MULTILINE)
            exec_cmd_original = exec_match.group(1) if exec_match else ""

            # Extract Path
            path_match = re.search(r'^Path=(.+)$', content, re.MULTILINE)
            path_value = path_match.group(1) if path_match else ""

            # Extract Icon
            icon_match = re.search(r'^Icon=(.+)$', content, re.MULTILINE)
            icon = icon_match.group(1) if icon_match else ""

            # Determine category based on exec, path, or icon (check for PortProton anywhere)
            is_portproton = any([
                "PortProton" in exec_cmd_original,
                "portproton" in exec_cmd_original.lower(),
                "PortProton" in path_value,
                "portproton" in path_value.lower(),
                "PortProton" in icon,
                "portproton" in icon.lower()
            ])

            category = "steam_proton" if is_portproton else "desktop"

            return {
                "name": name,
                "exec": exec_cmd_original,
                "image": icon if icon and os.path.exists(os.path.expanduser(icon)) else "",
                "category": category,
                "favorite": False,
                "last_played": 0,
                "source": "desktop"
            }

        except Exception as e:
            print(f"Error parsing desktop file {desktop_path}: {e}", file=sys.stderr)
            return None

    def scan_desktop_files(self) -> List[Dict[str, Any]]:
        """Scan .desktop files in applications directory and Desktop for PortProton games only"""
        games = []
        seen_games = set()  # Track game names to avoid duplicates

        # Scan both Desktop and applications directory (Desktop has priority)
        search_dirs = [
            Path.home() / "Bureau",  # Desktop folder (French locale) - Priority
            Path.home() / "Desktop",  # Desktop folder (English locale) - Priority
            Path.home() / ".local/share/applications"
        ]

        for applications_dir in search_dirs:
            if not applications_dir.exists():
                continue

            # Look for .desktop files that are PortProton games
            for desktop_file in applications_dir.glob("*.desktop"):
                try:
                    with open(desktop_file, 'r', encoding='utf-8') as f:
                        content = f.read()

                    # Only scan PortProton games (not generic desktop files)
                    if "PortProton" in content:
                        game_data = self.parse_desktop_file(desktop_file)
                        # Only add if it's a PortProton game (category steam_proton)
                        if game_data and game_data.get("category") == "steam_proton":
                            game_name = game_data.get("name", "")
                            # Skip if already seen (Desktop has priority over applications)
                            if game_name in seen_games:
                                continue

                            # Additional filter: skip Steam tools
                            if not any(tool in game_name.lower() for tool in ["millennium", "steam rom manager", "steamtools", "steam_proton", "steam linux runtime"]):
                                games.append(game_data)
                                seen_games.add(game_name)

                except Exception as e:
                    continue

        return games

    def scan_steam_shortcuts(self) -> List[Dict[str, Any]]:
        """Scan Steam shortcuts.vdf files for non-Steam games added to Steam"""
        games = []

        if not self.config.get("steam", {}).get("enabled", True):
            return games

        # Find Steam installation directory
        steam_paths = [
            Path.home() / ".local/share/Steam",
            Path.home() / ".steam/steam",
            Path.home() / "Game_Steam/steam",
        ]

        # Also check from library paths
        library_paths = self.config.get("steam", {}).get("library_paths", [])
        for lib_path_str in library_paths:
            lib_path = self.expand_path(lib_path_str)
            # Go up to steam root (steamapps -> steam)
            if lib_path.name == "steamapps" and lib_path.parent.exists():
                steam_paths.append(lib_path.parent)

        # Search for shortcuts.vdf in userdata directories
        for steam_path in steam_paths:
            if not steam_path.exists():
                continue

            userdata_path = steam_path / "userdata"
            if not userdata_path.exists():
                continue

            # Scan all user directories
            for user_dir in userdata_path.iterdir():
                if not user_dir.is_dir():
                    continue

                shortcuts_file = user_dir / "config" / "shortcuts.vdf"
                if shortcuts_file.exists():
                    print(f"Found shortcuts.vdf: {shortcuts_file}", file=sys.stderr)
                    shortcuts = self.parse_vdf_shortcuts(shortcuts_file)
                    games.extend(shortcuts)

        return games

    def scan_heroic_library(self) -> List[Dict[str, Any]]:
        """Scan Heroic Games Launcher library (Epic, GOG, Amazon, Sideload)"""
        games = []

        heroic_config = self.config.get("heroic", {})
        if not heroic_config.get("enabled", True):
            return games

        # Get config paths (support multiple paths)
        config_paths = heroic_config.get("config_paths", ["~/.config/heroic"])
        if isinstance(config_paths, str):
            config_paths = [config_paths]

        # Get scan options
        scan_epic = heroic_config.get("scan_epic", True)
        scan_gog = heroic_config.get("scan_gog", True)
        scan_amazon = heroic_config.get("scan_amazon", True)
        scan_sideload = heroic_config.get("scan_sideload", True)

        # Map of library file to runner type and scan flag
        libraries = {}
        if scan_epic:
            libraries["legendary_library.json"] = "epic"
        if scan_gog:
            libraries["gog_library.json"] = "gog"
        if scan_amazon:
            libraries["nile_library.json"] = "amazon"

        # Scan each config path
        for config_path_str in config_paths:
            heroic_path = self.expand_path(config_path_str)

            if not heroic_path.exists():
                continue

            # Scan store libraries (Epic, GOG, Amazon)
            for lib_file, runner in libraries.items():
                lib_path = heroic_path / "store_cache" / lib_file
                if lib_path.exists():
                    try:
                        with open(lib_path, 'r') as f:
                            data = json.load(f)

                        # Handle library format (list or dict of games)
                        game_list = data.get("library", []) if isinstance(data, dict) else data

                        for game_data in game_list:
                            if isinstance(game_data, dict) and game_data.get("is_installed", False):
                                app_name = game_data.get("app_name", "")
                                title = game_data.get("title", game_data.get("name", "Unknown"))

                                # Build launch command
                                exec_cmd = f"heroic://launch/{runner}/{app_name}"

                                games.append({
                                    "name": title,
                                    "exec": exec_cmd,
                                    "image": game_data.get("art_cover", game_data.get("art_square", "")),
                                    "category": runner,
                                    "favorite": False,
                                    "source": runner,
                                    "last_played": 0,
                                    "appid": app_name
                                })
                    except Exception as e:
                        print(f"Error loading Heroic {runner} library from {heroic_path}: {e}", file=sys.stderr)

            # Scan sideload apps
            if scan_sideload:
                sideload_path = heroic_path / "sideload_apps" / "library.json"
                if sideload_path.exists():
                    try:
                        with open(sideload_path, 'r') as f:
                            data = json.load(f)

                        for game in data.get("games", []):
                            if game.get("is_installed", False):
                                app_name = game.get("app_name", "")
                                title = game.get("title", "Unknown")

                                exec_cmd = f"heroic://launch/sideload/{app_name}"

                                games.append({
                                    "name": title,
                                    "exec": exec_cmd,
                                    "image": game.get("art_cover", game.get("art_square", "")),
                                    "category": "sideload",
                                    "favorite": False,
                                    "source": "heroic",
                                    "last_played": 0,
                                    "appid": app_name
                                })
                    except Exception as e:
                        print(f"Error loading Heroic sideload apps from {heroic_path}: {e}", file=sys.stderr)

        return games

    def load_manual_games(self) -> List[Dict[str, Any]]:
        """Load manually configured games from games.toml"""
        games = []
        games_toml_path = self.config_path.parent / "games.toml"

        if not games_toml_path.exists():
            return games

        try:
            with open(games_toml_path, 'rb') as f:
                data = tomllib.load(f)

            for game in data.get("games", []):
                # Expand image path
                if "image" in game:
                    game["image"] = str(self.expand_path(game["image"]))

                game["source"] = "manual"
                game["last_played"] = game.get("last_played", 0)
                games.append(game)

        except Exception as e:
            print(f"Error loading manual games: {e}", file=sys.stderr)

        return games

    def load_config_entries(self) -> List[Dict[str, Any]]:
        """Load game entries from config.toml"""
        games = []

        # Get box_art_dir from config (can be in animations section or top-level)
        box_art_dir = self.config.get("box_art_dir") or self.config.get("animations", {}).get("box_art_dir", "")
        if box_art_dir:
            box_art_dir = self.expand_path(box_art_dir)

        # Get entries from config
        entries = self.config.get("entries", [])

        for entry in entries:
            title = entry.get("title", "Unknown")
            launch_command = entry.get("launch_command", "")
            path_box_art = entry.get("path_box_art", "")

            # Construct full image path
            image_path = ""
            if path_box_art and box_art_dir:
                image_path = str(box_art_dir / path_box_art)
            elif path_box_art:
                image_path = str(self.expand_path(path_box_art))

            games.append({
                "name": title,
                "exec": launch_command,
                "image": image_path,
                "category": "launcher",
                "favorite": False,
                "source": "config",
                "last_played": 0
            })

        return games

    def merge_games(self) -> List[Dict[str, Any]]:
        """Merge Steam, Heroic, manual games, desktop files, and config entries, avoiding duplicates"""
        steam_games = self.scan_steam_library()
        steam_shortcuts = self.scan_steam_shortcuts()
        desktop_games = self.scan_desktop_files()
        heroic_games = self.scan_heroic_library()
        manual_games = self.load_manual_games()
        config_entries = self.load_config_entries()

        # Use dict to avoid duplicates (keyed by name)
        games_dict = {}

        # Add Steam games first (highest priority for images)
        for game in steam_games:
            games_dict[game["name"]] = game

        # Add Steam non-Steam games (shortcuts)
        for game in steam_shortcuts:
            if game["name"] in games_dict:
                games_dict[game["name"]].update(game)
            else:
                games_dict[game["name"]] = game

        # Add Heroic games
        for game in heroic_games:
            if game["name"] in games_dict:
                games_dict[game["name"]].update(game)
            else:
                games_dict[game["name"]] = game

        # Add config entries
        for game in config_entries:
            if game["name"] in games_dict:
                games_dict[game["name"]].update(game)
            else:
                games_dict[game["name"]] = game

        # Add .desktop file games (only if not already present - lowest priority)
        for game in desktop_games:
            if game["name"] not in games_dict:
                games_dict[game["name"]] = game

        # Add/override with manual games (highest priority)
        for game in manual_games:
            if game["name"] in games_dict:
                # Manual entry overrides Steam/Heroic entry
                games_dict[game["name"]].update(game)
            else:
                games_dict[game["name"]] = game

        return list(games_dict.values())

    def sort_games(self, games: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Sort games based on configuration"""
        sort_by = self.config.get("behavior", {}).get("sort_by", "name")
        show_favorites_first = self.config.get("behavior", {}).get("show_favorites_first", True)

        # Sort by favorites first if enabled
        if show_favorites_first:
            games.sort(key=lambda g: (not g.get("favorite", False)))

        # Then apply secondary sort
        if sort_by == "recent":
            games.sort(key=lambda g: g.get("last_played", 0), reverse=True)
        elif sort_by == "playtime":
            games.sort(key=lambda g: g.get("playtime", 0), reverse=True)
        elif sort_by == "name":
            games.sort(key=lambda g: g.get("name", "").lower())

        return games

    def load_wallust_colors(self) -> Dict[str, str]:
        """Load colors from wallust cache and flatten structure"""
        wallust_path = self.expand_path(
            self.config.get("appearance", {}).get("wallust_path", "~/.cache/wal/wal.json")
        )

        try:
            with open(wallust_path, 'r') as f:
                data = json.load(f)

            # Flatten the structure for easier QML access
            colors = {}

            # Add special colors (background, foreground, cursor)
            if "special" in data:
                colors.update(data["special"])

            # Add color palette (color0-color15)
            if "colors" in data:
                colors.update(data["colors"])

            return colors
        except Exception as e:
            print(f"Error loading wallust colors: {e}", file=sys.stderr)
            return {}

    def get_all_games(self) -> Dict[str, Any]:
        """Get all games and metadata"""
        games = self.merge_games()
        games = self.sort_games(games)

        wallust_colors = {}
        if self.config.get("appearance", {}).get("use_wallust", True):
            wallust_colors = self.load_wallust_colors()

        return {
            "games": games,
            "config": self.config,
            "colors": wallust_colors
        }

    def output_json(self):
        """Output games as JSON to stdout"""
        data = self.get_all_games()
        print(json.dumps(data, indent=2))


def main():
    """Main entry point"""
    launcher = GameLauncher()
    launcher.output_json()


if __name__ == "__main__":
    main()
