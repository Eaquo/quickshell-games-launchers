#!/usr/bin/env python3
import binascii
import json
import os
import re
import sqlite3
import struct
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import vdf

from .sgdb import SGDBClient


def expand_path(path: str) -> Path:
    return Path(os.path.expanduser(os.path.expandvars(path)))


class GameScanner:
    def __init__(self, config: Dict[str, Any], sgdb: Optional[SGDBClient] = None):
        self.config = config
        self.sgdb = sgdb
        self._heroic_bin: Optional[str] = self._detect_heroic()
        self._lutris_bin: Optional[str] = self._detect_lutris()

    # ── Détection Lutris ───────────────────────────────────────────────────

    def _detect_lutris(self) -> Optional[str]:
        import shutil

        if shutil.which("lutris"):
            return "lutris"
        flatpak_paths = [
            Path("/var/lib/flatpak/app/net.lutris.Lutris"),
            Path.home() / ".local/share/flatpak/app/net.lutris.Lutris",
        ]
        for p in flatpak_paths:
            if p.exists():
                return "flatpak run net.lutris.Lutris"
        return None

    def get_lutris_exec(self, game_id: int) -> str:
        url = f"lutris:rungameid/{game_id}"
        if self._lutris_bin is None:
            return f"xdg-open {url}"
        return f"{self._lutris_bin} {url}"

    # ── Détection Heroic ───────────────────────────────────────────────────

    def _detect_heroic(self) -> Optional[str]:
        import shutil

        if shutil.which("heroic"):
            return "heroic"
        search_dirs = [
            Path.home() / "Applications",
            Path.home() / "Downloads",
            Path.home() / ".local/bin",
            Path.home(),
            Path("/opt"),
        ]
        for directory in search_dirs:
            if not directory.exists():
                continue
            for appimage in directory.glob("*eroic*.AppImage"):
                if ".local/share/Trash" in str(appimage):
                    continue
                if os.access(appimage, os.X_OK):
                    return str(appimage)
        flatpak_paths = [
            Path("/var/lib/flatpak/app/com.heroicgameslauncher.hgl"),
            Path.home() / ".local/share/flatpak/app/com.heroicgameslauncher.hgl",
        ]
        for p in flatpak_paths:
            if p.exists():
                return "flatpak run com.heroicgameslauncher.hgl"
        return None

    def get_heroic_exec(self, runner: str, app_name: str) -> str:
        url = f"heroic://launch/{runner}/{app_name}"
        if self._heroic_bin is None:
            return f"xdg-open {url}"
        return f"{self._heroic_bin} {url}"

    # ── Steam ──────────────────────────────────────────────────────────────

    def load_steam_localconfig(self) -> Dict[str, Dict[str, int]]:
        result = {}
        userdata = Path.home() / ".local/share/Steam/userdata"
        if not userdata.exists():
            return result
        for user_dir in userdata.iterdir():
            cfg = user_dir / "config" / "localconfig.vdf"
            if not cfg.exists():
                continue
            try:
                content = cfg.read_text(encoding="utf-8", errors="ignore")
                apps_match = re.search(r'"apps"\s*\{', content)
                if not apps_match:
                    continue
                apps_content = content[apps_match.end() :]
                pos = 0
                while pos < len(apps_content):
                    m = re.search(r'"(\d+)"\s*\{', apps_content[pos:])
                    if not m:
                        break
                    appid = m.group(1)
                    block_start = pos + m.end()
                    depth = 1
                    p = block_start
                    while p < len(apps_content) and depth > 0:
                        if apps_content[p] == "{":
                            depth += 1
                        elif apps_content[p] == "}":
                            depth -= 1
                        p += 1
                    block = apps_content[block_start : p - 1]
                    pt = re.search(r'"Playtime"\s+"(\d+)"', block)
                    lp = re.search(r'"LastPlayed"\s+"(\d+)"', block)
                    if pt or lp:
                        result[appid] = {
                            "playtime_minutes": int(pt.group(1)) if pt else 0,
                            "last_played": int(lp.group(1)) if lp else 0,
                        }
                    pos = pos + m.start() + 1
            except (OSError, re.error) as e:
                print(f"[scanners] failed to parse {cfg}: {e}", file=sys.stderr)
        return result

    def is_steam_tool(self, name: str) -> bool:
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
            "compatibility tool",
        ]
        return any(pattern in name.lower() for pattern in tool_patterns)

    def parse_acf_file(self, acf_path: Path) -> Optional[Dict[str, Any]]:
        try:
            with open(acf_path, "r", encoding="utf-8", errors="ignore") as f:
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

            size_match = re.search(r'"SizeOnDisk"\s+"(\d+)"', content)
            size_bytes = int(size_match.group(1)) if size_match else 0

            updated_match = re.search(r'"LastUpdated"\s+"(\d+)"', content)
            last_updated = int(updated_match.group(1)) if updated_match else 0

            sgdb_config = self.config.get("steamgriddb", {})
            sgdb_active = sgdb_config.get("enabled", False) and bool(
                sgdb_config.get("api_key", "")
            )
            cdn_cover = (
                f"https://cdn.cloudflare.steamstatic.com/steam/apps/{app_id}/header.jpg"
            )
            cover_url = (
                ""
                if (sgdb_active and sgdb_config.get("parallel_requests", True))
                else cdn_cover
            )

            return {
                "name": name,
                "exec": f"steam steam://rungameid/{app_id}",
                "image": cover_url,
                "hero_image": f"https://cdn.cloudflare.steamstatic.com/steam/apps/{app_id}/library_hero.jpg",
                "category": "steam",
                "favorite": False,
                "appid": app_id,
                "last_played": last_played,
                "playtime_minutes": 0,
                "size_bytes": size_bytes,
                "last_updated": last_updated,
                "source": "steam",
                "logo": "",
            }
        except Exception as e:
            print(
                f"[scanners] could not parse ACF {acf_path.name}: {e}", file=sys.stderr
            )
            return None

    def scan_steam_library(self) -> List[Dict[str, Any]]:
        games = []
        if not self.config.get("steam", {}).get("enabled", True):
            return games
        localconfig = self.load_steam_localconfig()
        library_paths = self.config.get("steam", {}).get("library_paths", [])
        for lib_path in library_paths:
            lib_path = expand_path(lib_path)
            if not lib_path.exists():
                continue
            for acf_file in lib_path.glob("*.acf"):
                game_data = self.parse_acf_file(acf_file)
                if game_data:
                    appid = game_data.get("appid", "")
                    lc = localconfig.get(appid, {})
                    game_data["playtime_minutes"] = lc.get("playtime_minutes", 0)
                    if game_data.get("last_played", 0) == 0:
                        game_data["last_played"] = lc.get("last_played", 0)
                    games.append(game_data)
        return games

    def convert_appid_to_long(self, appid: int) -> int:
        int32 = struct.Struct("<i")
        bin_appid = int32.pack(appid)
        hex_appid = binascii.hexlify(bin_appid).decode()
        reversed_hex = bytes.fromhex(hex_appid)[::-1].hex()
        return int(reversed_hex, 16) << 32 | 0x02000000

    def parse_vdf_shortcuts(self, file_path: Path) -> List[Dict[str, Any]]:
        games = []
        try:
            with open(file_path, "rb") as f:
                shortcuts_data = vdf.binary_load(f)
            for _, app in shortcuts_data.get("shortcuts", {}).items():
                game_data = self.process_shortcut_entry(app)
                if game_data:
                    games.append(game_data)
        except Exception as e:
            print(
                f"[scanners] failed to parse shortcuts {file_path}: {e}",
                file=sys.stderr,
            )
        return games

    def process_shortcut_entry(self, app: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        name = app.get("AppName", app.get("appname", "Unknown"))
        exe = app.get("Exe", app.get("exe", ""))
        icon = app.get("icon", "")
        appid = app.get("appid", 0)
        last_played = app.get("LastPlayTime", app.get("lastplaytime", 0))

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
            "source": "steam",
        }

    def scan_steam_shortcuts(self) -> List[Dict[str, Any]]:
        games = []
        if not self.config.get("steam", {}).get("enabled", True):
            return games
        localconfig = self.load_steam_localconfig()
        userdata_path = expand_path("~/.local/share/Steam") / "userdata"
        if not userdata_path.exists():
            return games
        for user_dir in userdata_path.iterdir():
            if user_dir.is_dir():
                shortcuts_file = user_dir / "config" / "shortcuts.vdf"
                if shortcuts_file.exists():
                    shortcut_games = self.parse_vdf_shortcuts(shortcuts_file)
                    for g in shortcut_games:
                        appid = g.get("appid", "")
                        lc = localconfig.get(str(appid), {})
                        if lc.get("playtime_minutes", 0) > 0:
                            g["playtime_minutes"] = lc["playtime_minutes"]
                        if g.get("last_played", 0) == 0:
                            g["last_played"] = lc.get("last_played", 0)
                    games.extend(shortcut_games)
        return games

    # ── Desktop ────────────────────────────────────────────────────────────

    def scan_desktop_files(self) -> List[Dict[str, Any]]:
        games = []
        desktop_dirs = [
            Path.home() / ".local/share/applications",
            Path("/usr/share/applications"),
            Path("/usr/local/share/applications"),
        ]
        for desktop_dir in desktop_dirs:
            if not desktop_dir.exists():
                continue
            for desktop_file in desktop_dir.glob("*.desktop"):
                game_data = self.parse_desktop_file(desktop_file)
                if game_data:
                    games.append(game_data)
        return games

    def parse_desktop_file(self, desktop_path: Path) -> Optional[Dict[str, Any]]:
        try:
            with open(desktop_path, "r", encoding="utf-8") as f:
                content = f.read()
            if "Categories=" not in content or "Game" not in content:
                return None
            name_match = re.search(r"^Name=(.+)$", content, re.MULTILINE)
            if not name_match:
                return None
            exec_match = re.search(r"^Exec=(.+)$", content, re.MULTILINE)
            if not exec_match:
                return None
            icon_match = re.search(r"^Icon=(.+)$", content, re.MULTILINE)
            icon = icon_match.group(1) if icon_match else ""
            image_path = self.resolve_icon_path(icon) if icon else ""
            return {
                "name": name_match.group(1),
                "exec": exec_match.group(1),
                "image": image_path,
                "category": "desktop",
                "favorite": False,
                "source": "desktop",
                "last_played": 0,
            }
        except Exception as e:
            print(
                f"[scanners] could not parse desktop file {desktop_path.name}: {e}",
                file=sys.stderr,
            )
            return None

    def resolve_icon_path(self, icon: str) -> str:
        if icon.startswith("/"):
            return icon
        icon_dirs = [
            Path.home() / ".local/share/icons",
            Path("/usr/share/icons"),
            Path("/usr/share/pixmaps"),
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

    # ── Heroic ─────────────────────────────────────────────────────────────

    def scan_heroic_library(self) -> List[Dict[str, Any]]:
        games = []
        if not self.config.get("heroic", {}).get("enabled", True):
            return games

        config_paths = self.config.get("heroic", {}).get("config_paths", [])
        scan_epic = self.config.get("heroic", {}).get("scan_epic", True)
        scan_gog = self.config.get("heroic", {}).get("scan_gog", True)
        scan_amazon = self.config.get("heroic", {}).get("scan_amazon", True)
        scan_sideload = self.config.get("heroic", {}).get("scan_sideload", True)
        use_parallel = self.config.get("steamgriddb", {}).get("parallel_requests", True)

        for config_path in config_paths:
            heroic_path = expand_path(config_path)
            if not heroic_path.exists():
                continue

            stores = []
            if scan_epic:
                stores.append(("legendary", "epic"))
            if scan_gog:
                stores.append(("gog_store", "gog"))
            if scan_amazon:
                stores.append(("nile_config", "amazon"))

            for store_dir, runner in stores:
                library_path = heroic_path / "store_cache" / store_dir / "library.json"
                installed_path = (
                    heroic_path / "store_cache" / store_dir / "installed.json"
                )
                if not library_path.exists():
                    continue
                try:
                    with open(library_path, "r") as f:
                        data = json.load(f)
                    installed_games = set()
                    if installed_path.exists():
                        with open(installed_path, "r") as f:
                            installed_data = json.load(f)
                            installed_games = {
                                g.get("app_name", "")
                                for g in installed_data.get("installed", [])
                            }
                    for game in data.get("library", []):
                        app_name = game.get("app_name", "")
                        if app_name not in installed_games:
                            continue
                        title = game.get("title", "Unknown")
                        art = game.get("art_cover", game.get("art_square", ""))
                        if use_parallel or self.sgdb is None:
                            cover_url = art
                        else:
                            cover_url = self.sgdb.get_heroic_cover_url(
                                app_name, runner, art
                            )
                        games.append(
                            {
                                "name": title,
                                "exec": self.get_heroic_exec(runner, app_name),
                                "image": cover_url,
                                "category": runner,
                                "favorite": False,
                                "source": runner,
                                "last_played": 0,
                                "appid": app_name,
                                "logo": "",
                            }
                        )
                except Exception as e:
                    print(
                        f"[scanners] heroic store {store_dir} failed: {e}",
                        file=sys.stderr,
                    )

            if scan_sideload:
                sideload_path = heroic_path / "sideload_apps" / "library.json"
                if sideload_path.exists():
                    try:
                        with open(sideload_path, "r") as f:
                            data = json.load(f)
                        for game in data.get("games", []):
                            if not game.get("is_installed", False):
                                continue
                            app_name = game.get("app_name", "")
                            title = game.get("title", "Unknown")
                            art = game.get("art_cover", game.get("art_square", ""))
                            if use_parallel or self.sgdb is None:
                                cover_url = art
                            else:
                                cover_url = self.sgdb.get_heroic_cover_url(
                                    app_name, "sideload", art
                                )
                            games.append(
                                {
                                    "name": title,
                                    "exec": self.get_heroic_exec("sideload", app_name),
                                    "image": cover_url,
                                    "category": "sideload",
                                    "favorite": False,
                                    "source": "heroic",
                                    "last_played": 0,
                                    "appid": app_name,
                                    "logo": "",
                                }
                            )
                    except Exception as e:
                        print(
                            f"[scanners] heroic sideload failed: {e}", file=sys.stderr
                        )

        return games

    # ── Lutris ─────────────────────────────────────────────────────────────

    def scan_lutris_library(self) -> List[Dict[str, Any]]:
        games = []
        if not self.config.get("lutris", {}).get("enabled", False):
            return games

        db_path = expand_path(
            self.config.get("lutris", {}).get("db_path", "~/.local/share/lutris/pga.db")
        )
        if not db_path.exists():
            return games

        coverart_dir = expand_path("~/.local/share/lutris/coverart")
        try:
            con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
            con.row_factory = sqlite3.Row
            cur = con.cursor()
            cur.execute(
                "SELECT id, name, slug, runner, lastplayed, installed "
                "FROM games WHERE installed = 1"
            )
            rows = cur.fetchall()
            con.close()
        except Exception as e:
            print(f"[lutris] Error reading database: {e}", file=sys.stderr)
            return games

        for row in rows:
            name = row["name"] or ""
            if not name:
                continue
            slug = row["slug"] or ""
            game_id = row["id"]
            image_path = ""
            for ext in ("jpg", "jpeg", "png"):
                candidate = coverart_dir / f"{slug}.{ext}"
                if candidate.exists():
                    image_path = str(candidate)
                    break
            games.append(
                {
                    "name": name,
                    "exec": self.get_lutris_exec(game_id),
                    "image": image_path,
                    "category": "lutris",
                    "favorite": False,
                    "source": "lutris",
                    "last_played": row["lastplayed"] or 0,
                    "appid": str(game_id),
                    "logo": "",
                }
            )

        return games
