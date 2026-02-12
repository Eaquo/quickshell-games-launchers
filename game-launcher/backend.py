#!/usr/bin/env python3
"""
Game Launcher Backend - OPTIMIZED VERSION
Features: Image URL caching, parallel requests, smart Steam CDN fallbacks
"""

import json
import os
import sys
import tomllib
from pathlib import Path
from typing import List, Dict, Any, Optional
import re
import urllib.request
import urllib.error
import struct
import binascii
import vdf
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta


class ImageCache:
    """Cache for image URLs to avoid repeated API calls"""
    
    def __init__(self, cache_file: Path, ttl_hours: int = 24):
        self.cache_file = cache_file
        self.ttl = timedelta(hours=ttl_hours)
        self.cache = self._load_cache()
    
    def _load_cache(self) -> Dict[str, Any]:
        if not self.cache_file.exists():
            return {}
        try:
            with open(self.cache_file, 'r') as f:
                return json.load(f)
        except Exception:
            return {}
    
    def _save_cache(self):
        try:
            self.cache_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.cache_file, 'w') as f:
                json.dump(self.cache, f, indent=2)
        except Exception as e:
            print(f"Error saving cache: {e}", file=sys.stderr)
    
    def get(self, key: str) -> Optional[str]:
        if key not in self.cache:
            return None
        
        entry = self.cache[key]
        cached_time = datetime.fromisoformat(entry['timestamp'])
        
        if datetime.now() - cached_time > self.ttl:
            del self.cache[key]
            return None
        
        return entry['url']
    
    def set(self, key: str, url: str):
        self.cache[key] = {
            'url': url,
            'timestamp': datetime.now().isoformat()
        }
        self._save_cache()
    
    def clear_expired(self):
        now = datetime.now()
        expired_keys = [k for k, v in self.cache.items() 
                       if now - datetime.fromisoformat(v['timestamp']) > self.ttl]
        
        for key in expired_keys:
            del self.cache[key]
        
        if expired_keys:
            self._save_cache()


class GameLauncher:
    def __init__(self, config_path: str = None):
        if config_path is None:
            config_path = Path.home() / ".config/quickshell/game-launcher/config.toml"

        self.config_path = Path(config_path)
        self.config = self.load_config()
        
        # Initialize image cache
        cache_dir = self.config_path.parent / "cache"
        cache_file = cache_dir / "image_cache.json"
        cache_ttl = self.config.get("steamgriddb", {}).get("cache_ttl_hours", 24)
        self.image_cache = ImageCache(cache_file, ttl_hours=cache_ttl)
        self.image_cache.clear_expired()

    def load_config(self) -> Dict[str, Any]:
        try:
            with open(self.config_path, 'rb') as f:
                return tomllib.load(f)
        except Exception as e:
            print(f"Error loading config: {e}", file=sys.stderr)
            return self.get_default_config()

    def get_default_config(self) -> Dict[str, Any]:
        return {
            "steam": {
                "enabled": True,
                "library_paths": ["~/.local/share/Steam/steamapps"],
                "fetch_covers": True
            },
            "steamgriddb": {
                "enabled": False,
                "api_key": "",
                "image_type": "grid",
                "prefer_animated": False,
                "fallback_to_steam": True,
                "dimensions": [],
                "styles": [],
                "mimes": [],
                "nsfw": "false",
                "humor": "false",
                "epilepsy": "false",
                "cache_ttl_hours": 24,
                "parallel_requests": True,
                "max_workers": 10,
                "request_timeout": 3
            },
            "heroic": {
                "enabled": True,
                "config_paths": ["~/.config/heroic"],
                "scan_epic": True,
                "scan_gog": True,
                "scan_amazon": True,
                "scan_sideload": True
            },
            "filtering": {
                "games_only": False,
                "exclude_categories": [],
                "exclude_keywords": []
            },
            "behavior": {
                "sort_by": "recent",
                "show_favorites_first": True
            }
        }

    def expand_path(self, path: str) -> Path:
        return Path(os.path.expanduser(os.path.expandvars(path)))

    def check_url_exists(self, url: str, timeout: int = 2) -> bool:
        """Check if an image URL returns 200 OK"""
        try:
            request = urllib.request.Request(url, method='HEAD')
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.status == 200
        except Exception:
            return False

    def get_steam_cdn_fallback_url(self, app_id: str) -> str:
        """Get Steam CDN image with smart fallbacks - tries multiple URLs"""
        base_url = f"https://cdn.cloudflare.steamstatic.com/steam/apps/{app_id}"
        
        # Check cache first
        cache_key = f"steam_cdn:{app_id}"
        cached_url = self.image_cache.get(cache_key)
        if cached_url:
            return cached_url
        
        # Try URLs in order of preference
        fallback_urls = [
            f"{base_url}/header.jpg",           # Horizontal banner (460x215)
            f"{base_url}/library_600x900.jpg",  # Vertical portrait
            f"{base_url}/capsule_616x353.jpg",  # Medium capsule
            f"{base_url}/library_hero.jpg",     # Large hero image
        ]
        
        # Quick check - try first URL without validation
        first_url = fallback_urls[0]
        if self.check_url_exists(first_url, timeout=1):
            self.image_cache.set(cache_key, first_url)
            return first_url
        
        # If first fails, try others
        for url in fallback_urls[1:]:
            if self.check_url_exists(url, timeout=1):
                self.image_cache.set(cache_key, url)
                return url
        
        # If all fail, return first one anyway (let QML handle it)
        return first_url

    def get_steamgriddb_cover_url(self, app_id: str, platform: str = "steam") -> Optional[str]:
        """Get cover image from SteamGridDB API with caching"""
        sgdb_config = self.config.get("steamgriddb", {})
        
        if not sgdb_config.get("enabled", False):
            return None
            
        api_key = sgdb_config.get("api_key", "")
        if not api_key:
            return None

        # Check cache first
        cache_key = f"{platform}:{app_id}:{sgdb_config.get('image_type', 'grid')}"
        cached_url = self.image_cache.get(cache_key)
        if cached_url:
            return cached_url if cached_url else None  # Empty string means no image found

        image_type = sgdb_config.get("image_type", "grid")
        endpoint_map = {
            "grid": "grids",
            "hero": "heroes",
            "logo": "logos",
            "icon": "icons"
        }
        
        endpoint = endpoint_map.get(image_type, "grids")
        url = f"https://www.steamgriddb.com/api/v2/{endpoint}/{platform}/{app_id}"
        
        # Build query parameters
        params = []
        
        if sgdb_config.get("prefer_animated", False):
            params.append("types=animated")
        else:
            params.append("types=static")
        
        dimensions = sgdb_config.get("dimensions", [])
        if dimensions:
            params.append(f"dimensions={','.join(dimensions)}")
        
        styles = sgdb_config.get("styles", [])
        if styles:
            params.append(f"styles={','.join(styles)}")
        
        mimes = sgdb_config.get("mimes", [])
        if mimes:
            params.append(f"mimes={','.join(mimes)}")
        
        params.append(f"nsfw={sgdb_config.get('nsfw', 'false')}")
        params.append(f"humor={sgdb_config.get('humor', 'false')}")
        params.append(f"epilepsy={sgdb_config.get('epilepsy', 'false')}")
        
        if params:
            url += "?" + "&".join(params)
        
        timeout = sgdb_config.get("request_timeout", 3)
        
        try:
            request = urllib.request.Request(url)
            request.add_header("Authorization", f"Bearer {api_key}")
            request.add_header("User-Agent", "QuickShell-GameLauncher/2.0")
            request.add_header("Accept", "application/json")
            
            with urllib.request.urlopen(request, timeout=timeout) as response:
                data = json.loads(response.read().decode())
                
                if data.get("success") and data.get("data"):
                    images = data["data"]
                    if images:
                        image_url = images[0].get("url", images[0].get("thumb"))
                        self.image_cache.set(cache_key, image_url)
                        return image_url
                        
        except urllib.error.HTTPError as e:
            if e.code == 404:
                # Cache empty result to avoid retrying
                self.image_cache.set(cache_key, "")
        except Exception:
            pass
        
        return None

    def fetch_images_parallel(self, games: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Fetch images in parallel for faster loading"""
        sgdb_config = self.config.get("steamgriddb", {})
        
        if not sgdb_config.get("enabled", False) or not sgdb_config.get("parallel_requests", True):
            return games
        
        max_workers = sgdb_config.get("max_workers", 10)
        
        # Games that need image fetching
        games_to_fetch = []
        for i, game in enumerate(games):
            if game.get("source") in ["steam", "epic", "gog", "amazon"] and game.get("appid"):
                if not game.get("image") or "steamstatic.com" in game.get("image", ""):
                    games_to_fetch.append((i, game))
        
        if not games_to_fetch:
            return games
        
        def fetch_image(item):
            idx, game = item
            platform = self.get_steamgriddb_platform(game.get("source", ""), game.get("category", ""))
            
            # Try SteamGridDB first
            url = self.get_steamgriddb_cover_url(game.get("appid"), platform)
            
            # If SteamGridDB fails and it's a Steam game, try Steam CDN fallbacks
            if not url and game.get("source") == "steam":
                url = self.get_steam_cdn_fallback_url(game.get("appid"))
            
            return idx, url
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {executor.submit(fetch_image, item): item for item in games_to_fetch}
            
            for future in as_completed(futures):
                try:
                    idx, url = future.result()
                    if url:
                        games[idx]["image"] = url
                except Exception:
                    pass
        
        return games

    def get_steamgriddb_platform(self, source: str, category: str) -> str:
        """Map game source/category to SteamGridDB platform"""
        platform_map = {
            "steam": "steam",
            "epic": "egs",
            "gog": "gog",
            "amazon": "amazon",
            "uplay": "uplay",
            "origin": "origin",
            "battlenet": "bnet",
            "sideload": "steam",
        }
        
        return platform_map.get(source.lower()) or platform_map.get(category.lower()) or "steam"

    def get_steam_cover_url(self, app_id: str) -> str:
        """Get Steam cover URL with SteamGridDB and CDN fallbacks"""
        # Try SteamGridDB first if enabled
        sgdb_url = self.get_steamgriddb_cover_url(app_id, platform="steam")
        if sgdb_url:
            return sgdb_url
        
        # Fallback to Steam CDN with smart URL selection
        sgdb_config = self.config.get("steamgriddb", {})
        if sgdb_config.get("enabled", False) and not sgdb_config.get("fallback_to_steam", True):
            return ""
        
        return self.get_steam_cdn_fallback_url(app_id)
    
    def get_heroic_cover_url(self, app_id: str, source: str, art_url: str = "") -> str:
        """Get cover URL for Heroic games"""
        platform = self.get_steamgriddb_platform(source, source)
        sgdb_url = self.get_steamgriddb_cover_url(app_id, platform=platform)
        return sgdb_url if sgdb_url else art_url

    def scan_steam_library(self) -> List[Dict[str, Any]]:
        """Scan Steam library for installed games"""
        games = []

        if not self.config.get("steam", {}).get("enabled", True):
            return games

        library_paths = self.config.get("steam", {}).get("library_paths", [])

        for lib_path in library_paths:
            lib_path = self.expand_path(lib_path)

            if not lib_path.exists():
                continue

            for acf_file in lib_path.glob("*.acf"):
                game_data = self.parse_acf_file(acf_file)
                if game_data:
                    games.append(game_data)

        return games

    def is_steam_tool(self, name: str) -> bool:
        """Check if a Steam app is a tool/runtime"""
        tool_patterns = [
            "proton", "steam linux runtime", "steamworks common", "steam runtime",
            "redistributable", "sdk", "dedicated server", "tool", "hotfix",
            "steamvr", "steam audio", "steam shader", "steam workshop",
            "steam controller", "directx", "vcredist", "visual c++",
            ".net framework", "microsoft visual", "steam play", "compatibility tool"
        ]
        return any(pattern in name.lower() for pattern in tool_patterns)

    def parse_acf_file(self, acf_path: Path) -> Dict[str, Any]:
        """Parse Steam .acf manifest file"""
        try:
            with open(acf_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()

            app_id_match = re.search(r'"appid"\s+"(\d+)"', content)
            if not app_id_match:
                return None
            app_id = app_id_match.group(1)

            name_match = re.search(r'"name"\s+"([^"]+)"', content)
            if not name_match:
                return None
            name = name_match.group(1)

            if self.is_steam_tool(name):
                return None

            last_played_match = re.search(r'"LastPlayed"\s+"(\d+)"', content)
            last_played = int(last_played_match.group(1)) if last_played_match else 0

            # Image will be fetched in parallel if enabled
            sgdb_config = self.config.get("steamgriddb", {})
            cover_url = "" if sgdb_config.get("parallel_requests", True) else self.get_steam_cover_url(app_id)

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

        except Exception:
            return None

    def convert_appid_to_long(self, appid: int) -> int:
        """Convert short AppID to long AppID"""
        int32 = struct.Struct('<i')
        bin_appid = int32.pack(appid)
        hex_appid = binascii.hexlify(bin_appid).decode()
        reversed_hex = bytes.fromhex(hex_appid)[::-1].hex()
        return int(reversed_hex, 16) << 32 | 0x02000000

    def parse_vdf_shortcuts(self, file_path: Path) -> List[Dict[str, Any]]:
        """Parse Steam shortcuts.vdf"""
        games = []
        try:
            with open(file_path, 'rb') as f:
                shortcuts_data = vdf.binary_load(f)

            for idx, app in shortcuts_data.get('shortcuts', {}).items():
                game_data = self.process_shortcut_entry(app)
                if game_data:
                    games.append(game_data)
        except Exception:
            pass

        return games

    def process_shortcut_entry(self, app: Dict[str, Any]) -> Dict[str, Any]:
        """Parse a single shortcut entry"""
        name = app.get('AppName', app.get('appname', 'Unknown'))
        exe = app.get('Exe', app.get('exe', ''))
        icon = app.get('icon', '')
        appid = app.get('appid', 0)
        last_played = app.get('LastPlayTime', app.get('lastplaytime', 0))

        if not name or not exe:
            return None

        long_appid = self.convert_appid_to_long(appid)

        return {
            "name": name,
            "exec": f"steam steam://rungameid/{long_appid}",
            "image": icon if icon else "",
            "category": "steam-shortcut",
            "favorite": False,
            "appid": str(long_appid),
            "last_played": last_played,
            "source": "steam"
        }

    def scan_steam_shortcuts(self) -> List[Dict[str, Any]]:
        """Scan Steam shortcuts"""
        games = []
        if not self.config.get("steam", {}).get("enabled", True):
            return games

        steam_path = self.expand_path("~/.local/share/Steam")
        userdata_path = steam_path / "userdata"

        if not userdata_path.exists():
            return games

        for user_dir in userdata_path.iterdir():
            if user_dir.is_dir():
                shortcuts_file = user_dir / "config" / "shortcuts.vdf"
                if shortcuts_file.exists():
                    games.extend(self.parse_vdf_shortcuts(shortcuts_file))

        return games

    def scan_desktop_files(self) -> List[Dict[str, Any]]:
        """Scan .desktop files"""
        games = []
        desktop_dirs = [
            Path.home() / ".local/share/applications",
            Path("/usr/share/applications"),
            Path("/usr/local/share/applications")
        ]

        for desktop_dir in desktop_dirs:
            if not desktop_dir.exists():
                continue

            for desktop_file in desktop_dir.glob("*.desktop"):
                game_data = self.parse_desktop_file(desktop_file)
                if game_data:
                    games.append(game_data)

        return games

    def parse_desktop_file(self, desktop_path: Path) -> Dict[str, Any]:
        """Parse .desktop file"""
        try:
            with open(desktop_path, 'r', encoding='utf-8') as f:
                content = f.read()

            if "Categories=" not in content or "Game" not in content:
                return None

            name_match = re.search(r'^Name=(.+)$', content, re.MULTILINE)
            if not name_match:
                return None
            name = name_match.group(1)

            exec_match = re.search(r'^Exec=(.+)$', content, re.MULTILINE)
            if not exec_match:
                return None
            exec_cmd = exec_match.group(1)

            icon_match = re.search(r'^Icon=(.+)$', content, re.MULTILINE)
            icon = icon_match.group(1) if icon_match else ""
            image_path = self.resolve_icon_path(icon) if icon else ""

            return {
                "name": name,
                "exec": exec_cmd,
                "image": image_path,
                "category": "desktop",
                "favorite": False,
                "source": "desktop",
                "last_played": 0
            }

        except Exception:
            return None

    def resolve_icon_path(self, icon: str) -> str:
        """Resolve icon name to full path"""
        if icon.startswith("/"):
            return icon

        icon_dirs = [
            Path.home() / ".local/share/icons",
            Path("/usr/share/icons"),
            Path("/usr/share/pixmaps")
        ]

        for icon_dir in icon_dirs:
            if not icon_dir.exists():
                continue

            for ext in ["png", "svg", "jpg", "xpm"]:
                for size in ["256x256", "128x128", "64x64", "48x48"]:
                    icon_path = icon_dir / "hicolor" / size / "apps" / f"{icon}.{ext}"
                    if icon_path.exists():
                        return str(icon_path)

                icon_path = icon_dir / f"{icon}.{ext}"
                if icon_path.exists():
                    return str(icon_path)

        return icon

    def scan_heroic_library(self) -> List[Dict[str, Any]]:
        """Scan Heroic Games Launcher library"""
        games = []

        if not self.config.get("heroic", {}).get("enabled", True):
            return games

        config_paths = self.config.get("heroic", {}).get("config_paths", [])
        scan_epic = self.config.get("heroic", {}).get("scan_epic", True)
        scan_gog = self.config.get("heroic", {}).get("scan_gog", True)
        scan_amazon = self.config.get("heroic", {}).get("scan_amazon", True)
        scan_sideload = self.config.get("heroic", {}).get("scan_sideload", True)

        for config_path in config_paths:
            heroic_path = self.expand_path(config_path)

            if not heroic_path.exists():
                continue

            stores = []
            if scan_epic:
                stores.append(("legendary", "epic"))
            if scan_gog:
                stores.append(("gog_store", "gog"))
            if scan_amazon:
                stores.append(("nile_config", "amazon"))

            use_parallel = self.config.get("steamgriddb", {}).get("parallel_requests", True)

            for store_dir, runner in stores:
                library_path = heroic_path / "store_cache" / store_dir / "library.json"
                installed_path = heroic_path / "store_cache" / store_dir / "installed.json"

                if library_path.exists():
                    try:
                        with open(library_path, 'r') as f:
                            data = json.load(f)

                        installed_games = set()
                        if installed_path.exists():
                            with open(installed_path, 'r') as f:
                                installed_data = json.load(f)
                                installed_games = {g.get("app_name", "") for g in installed_data.get("installed", [])}

                        for game in data.get("library", []):
                            app_name = game.get("app_name", "")
                            if app_name not in installed_games:
                                continue

                            title = game.get("title", "Unknown")
                            art = game.get("art_cover", game.get("art_square", ""))
                            
                            cover_url = "" if use_parallel else self.get_heroic_cover_url(app_name, runner, art)

                            games.append({
                                "name": title,
                                "exec": f"heroic://launch/{runner}/{app_name}",
                                "image": cover_url,
                                "category": runner,
                                "favorite": False,
                                "source": runner,
                                "last_played": 0,
                                "appid": app_name
                            })
                    except Exception:
                        pass

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
                                art = game.get("art_cover", game.get("art_square", ""))
                                
                                cover_url = "" if use_parallel else self.get_heroic_cover_url(app_name, "sideload", art)

                                games.append({
                                    "name": title,
                                    "exec": f"heroic://launch/sideload/{app_name}",
                                    "image": cover_url,
                                    "category": "sideload",
                                    "favorite": False,
                                    "source": "heroic",
                                    "last_played": 0,
                                    "appid": app_name
                                })
                    except Exception:
                        pass

        return games

    def load_manual_games(self) -> List[Dict[str, Any]]:
        """Load manually configured games"""
        games = []
        games_toml_path = self.config_path.parent / "games.toml"

        if not games_toml_path.exists():
            return games

        try:
            with open(games_toml_path, 'rb') as f:
                data = tomllib.load(f)

            for game in data.get("games", []):
                if "image" in game:
                    game["image"] = str(self.expand_path(game["image"]))

                game["source"] = "manual"
                game["last_played"] = game.get("last_played", 0)
                games.append(game)

        except Exception:
            pass

        return games

    def load_config_entries(self) -> List[Dict[str, Any]]:
        """Load game entries from config.toml"""
        games = []

        box_art_dir = self.config.get("box_art_dir") or self.config.get("animations", {}).get("box_art_dir", "")
        if box_art_dir:
            box_art_dir = self.expand_path(box_art_dir)

        entries = self.config.get("entries", [])

        for entry in entries:
            title = entry.get("title", "Unknown")
            launch_command = entry.get("launch_command", "")
            path_box_art = entry.get("path_box_art", "")

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

    def should_include_game(self, game: Dict[str, Any]) -> bool:
        """Filter games based on config rules"""
        filtering = self.config.get("filtering", {})
        
        if filtering.get("games_only", False):
            category = game.get("category", "").lower()
            name = game.get("name", "").lower()
            
            if category in ["launcher", "desktop"]:
                if category == "desktop" and ("steam" in name or "heroic" in name or game.get("appid")):
                    pass
                else:
                    return False
            
            exclude_patterns = [
                "launcher", "manager", "runtime", "proton", "tool",
                "steamtools", "mod manager", "nexus mods", "vortex",
                "portproton", "protonup", "goverlay", "piper",
                "parsec", "moonlight", "millennium"
            ]
            
            if any(p in name for p in exclude_patterns):
                return False
        
        excluded_categories = filtering.get("exclude_categories", [])
        if game.get("category") in excluded_categories:
            return False
        
        excluded_keywords = filtering.get("exclude_keywords", [])
        game_name_lower = game.get("name", "").lower()
        if any(k.lower() in game_name_lower for k in excluded_keywords):
            return False
        
        return True

    def merge_games(self) -> List[Dict[str, Any]]:
        """Merge all game sources"""
        steam_games = self.scan_steam_library()
        steam_shortcuts = self.scan_steam_shortcuts()
        desktop_games = self.scan_desktop_files()
        heroic_games = self.scan_heroic_library()
        manual_games = self.load_manual_games()
        config_entries = self.load_config_entries()

        games_dict = {}

        for game in steam_games:
            if self.should_include_game(game):
                games_dict[game["name"]] = game

        for game in steam_shortcuts:
            if self.should_include_game(game):
                if game["name"] in games_dict:
                    games_dict[game["name"]].update(game)
                else:
                    games_dict[game["name"]] = game

        for game in heroic_games:
            if self.should_include_game(game):
                if game["name"] in games_dict:
                    games_dict[game["name"]].update(game)
                else:
                    games_dict[game["name"]] = game

        for game in config_entries:
            if self.should_include_game(game):
                if game["name"] in games_dict:
                    games_dict[game["name"]].update(game)
                else:
                    games_dict[game["name"]] = game

        for game in desktop_games:
            if self.should_include_game(game):
                if game["name"] not in games_dict:
                    games_dict[game["name"]] = game

        for game in manual_games:
            if game["name"] in games_dict:
                games_dict[game["name"]].update(game)
            else:
                games_dict[game["name"]] = game

        games = list(games_dict.values())
        
        # Fetch images in parallel if enabled
        sgdb_config = self.config.get("steamgriddb", {})
        if sgdb_config.get("enabled", False) and sgdb_config.get("parallel_requests", True):
            games = self.fetch_images_parallel(games)
        
        return games

    def sort_games(self, games: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Sort games"""
        sort_by = self.config.get("behavior", {}).get("sort_by", "name")
        show_favorites_first = self.config.get("behavior", {}).get("show_favorites_first", True)

        if show_favorites_first:
            games.sort(key=lambda g: (not g.get("favorite", False)))

        if sort_by == "recent":
            games.sort(key=lambda g: g.get("last_played", 0), reverse=True)
        elif sort_by == "playtime":
            games.sort(key=lambda g: g.get("playtime", 0), reverse=True)
        elif sort_by == "name":
            games.sort(key=lambda g: g.get("name", "").lower())

        return games

    def load_wallust_colors(self) -> Dict[str, str]:
        """Load colors from wallust cache"""
        wallust_path = self.expand_path(
            self.config.get("appearance", {}).get("wallust_path", "~/.cache/wal/wal.json")
        )

        try:
            with open(wallust_path, 'r') as f:
                data = json.load(f)

            colors = {}
            if "special" in data:
                colors.update(data["special"])
            if "colors" in data:
                colors.update(data["colors"])

            return colors
        except Exception:
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
    launcher = GameLauncher()
    launcher.output_json()


if __name__ == "__main__":
    main()
