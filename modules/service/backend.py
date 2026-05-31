#!/usr/bin/env python3
import json
import os
import re
import sys
import urllib.request
from pathlib import Path
from typing import Any, Dict, List

import tomllib

# Permet les imports absolus depuis modules/service/ quand lancé comme script
sys.path.insert(0, str(Path(__file__).parent))

from helpers.image_cache import ImageCache
from helpers.scanners import GameScanner, expand_path
from helpers.sgdb import SGDBClient


class GameLauncher:
    def __init__(self, config_path: str = None):
        if config_path is None:
            script_dir = Path(os.path.abspath(__file__)).parent
            config_path = script_dir.parent.parent / "config.toml"

        self.config_path = Path(config_path)
        self.favorites_file = self.config_path.parent / "favorites.json"
        self.state_file = self.config_path.parent / "state.json"
        self.config = self.load_config()
        self.migrate_config()

        cache_dir = self.config_path.parent / "cache"
        cache_ttl = self.config.get("steamgriddb", {}).get("cache_ttl_hours", 24)
        self.image_cache = ImageCache(
            cache_dir / "image_cache.json", ttl_hours=cache_ttl
        )
        self.image_cache.clear_expired()

        self.sgdb = SGDBClient(self.config, self.image_cache)
        self.scanner = GameScanner(self.config, self.sgdb)

    # ── Favoris ────────────────────────────────────────────────────────────

    def load_favorites(self) -> set:
        try:
            with open(self.favorites_file, "r") as f:
                return set(json.load(f))
        except Exception:
            return set()

    def save_favorites(self, favorites: set):
        try:
            with open(self.favorites_file, "w") as f:
                json.dump(sorted(favorites), f, indent=2)
        except Exception as e:
            print(f"Error saving favorites: {e}", file=sys.stderr)

    def toggle_favorite(self, name: str, source: str):
        key = f"{name}:{source}"
        favorites = self.load_favorites()
        if key in favorites:
            favorites.discard(key)
            is_fav = False
        else:
            favorites.add(key)
            is_fav = True
        self.save_favorites(favorites)
        print(json.dumps({"ok": True, "favorite": is_fav}), flush=True)

    # ── État (onglet/jeu mémorisé) ─────────────────────────────────────────

    def load_state(self) -> Dict[str, Any]:
        try:
            with open(self.state_file, "r") as f:
                return json.load(f)
        except Exception:
            return {}

    def save_state(self, key: str, value: Any):
        state = self.load_state()
        state[key] = value
        try:
            with open(self.state_file, "w") as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            print(f"Error saving state: {e}", file=sys.stderr)

    # ── Config ─────────────────────────────────────────────────────────────

    def load_config(self) -> Dict[str, Any]:
        try:
            with open(self.config_path, "rb") as f:
                return tomllib.load(f)
        except Exception as e:
            print(f"Error loading config: {e}", file=sys.stderr)
            return self.get_default_config()

    def migrate_config(self):
        """Insère les clés manquantes et déduplique dans config.toml."""
        NEW_KEYS = [
            (
                "behavior",
                "default_source_index",
                "0",
                "# Active source tab on startup: 0=All, 1=first tab, 2=second, etc.",
            ),
            (
                "behavior",
                "remember_source",
                "false",
                "# Remember the last active tab between sessions (overrides default_source_index)",
            ),
            (
                "steamgriddb",
                "fallback_to_steam",
                "true",
                "# Fall back to Steam CDN images when no SGDB cover is found",
            ),
            ("steamgriddb", "nsfw", "false", "# Include NSFW content"),
            ("steamgriddb", "humor", "false", "# Include humor / meme content"),
            (
                "steamgriddb",
                "epilepsy",
                "false",
                "# Include epilepsy-triggering content",
            ),
        ]
        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                original = f.read()
            content = original

            for _, key, _, _ in NEW_KEYS:
                seen, new_lines = False, []
                for line in content.split("\n"):
                    if re.match(rf"^\s*{re.escape(key)}\s*=", line):
                        if not seen:
                            new_lines.append(line)
                            seen = True
                    else:
                        new_lines.append(line)
                content = "\n".join(new_lines)

            for section, key, default, comment in NEW_KEYS:
                if re.search(rf"^\s*{re.escape(key)}\s*=", content, re.MULTILINE):
                    continue
                header = f"[{section}]"
                if header not in content:
                    content += f"\n{header}\n{comment}\n{key} = {default}\n"
                    continue
                pos = content.find(header)
                lines = content[pos:].split("\n")
                end_idx = len(lines)
                for i in range(1, len(lines)):
                    s = lines[i].strip()
                    if s.startswith("[") and not s.startswith("#") and s:
                        end_idx = i
                        break
                lines.insert(end_idx, f"\n{comment}\n{key} = {default}\n")
                content = content[:pos] + "\n".join(lines)

            if content != original:
                with open(self.config_path, "w", encoding="utf-8") as f:
                    f.write(content)
                self.config = self.load_config()
        except Exception as e:
            print(f"Config migration error: {e}", file=sys.stderr)

    def get_default_config(self) -> Dict[str, Any]:
        return {
            "steam": {
                "enabled": True,
                "library_paths": ["~/.local/share/Steam/steamapps"],
            },
            "steamgriddb": {
                "enabled": False,
                "api_key": "",
                "image_type": "grid",
                "prefer_animated": False,
                "fallback_to_steam": True,
                "dimensions": [],
                "styles": [],
                "cache_ttl_hours": 24,
                "parallel_requests": True,
                "max_workers": 10,
                "request_timeout": 3,
            },
            "heroic": {
                "enabled": True,
                "config_paths": ["~/.config/heroic"],
                "scan_epic": True,
                "scan_gog": True,
                "scan_amazon": True,
                "scan_sideload": True,
            },
            "filtering": {
                "games_only": False,
                "exclude_categories": [],
                "exclude_keywords": [],
            },
            "behavior": {"sort_by": "recent", "show_favorites_first": True},
        }

    # ── Entrées manuelles ──────────────────────────────────────────────────

    def load_manual_games(self) -> List[Dict[str, Any]]:
        games = []
        games_toml_path = self.config_path.parent / "games.toml"
        if not games_toml_path.exists():
            return games
        try:
            with open(games_toml_path, "rb") as f:
                data = tomllib.load(f)
            for game in data.get("games", []):
                if "image" in game:
                    game["image"] = str(expand_path(game["image"]))
                game["source"] = "manual"
                game["last_played"] = game.get("last_played", 0)
                games.append(game)
        except Exception as e:
            print(f"[backend] failed to load games.toml: {e}", file=sys.stderr)
        return games

    def load_config_entries(self) -> List[Dict[str, Any]]:
        games = []
        manual_cfg = self.config.get("manual", {})
        box_art_dir = (
            manual_cfg.get("box_art_dir")
            or self.config.get("animations", {}).get("box_art_dir")
            or self.config.get("box_art_dir", "")
        )
        if box_art_dir:
            box_art_dir = expand_path(box_art_dir)
        entries = manual_cfg.get("entries") or self.config.get("entries", [])
        for entry in entries:
            title = entry.get("title", "Unknown")
            launch_command = entry.get("launch_command", "")
            path_box_art = entry.get("path_box_art", "")
            if path_box_art and box_art_dir:
                image_path = str(box_art_dir / path_box_art)
            elif path_box_art:
                image_path = str(expand_path(path_box_art))
            else:
                image_path = ""
            games.append(
                {
                    "name": title,
                    "exec": launch_command,
                    "image": image_path,
                    "category": "launcher",
                    "favorite": False,
                    "source": "config",
                    "last_played": 0,
                    "logo": "",
                }
            )
        return games

    # ── Filtrage / tri ─────────────────────────────────────────────────────

    def should_include_game(self, game: Dict[str, Any]) -> bool:
        filtering = self.config.get("filtering", {})
        if filtering.get("games_only", False):
            category = game.get("category", "").lower()
            name = game.get("name", "").lower()
            if category in ["launcher", "desktop"]:
                if not (
                    category == "desktop"
                    and ("steam" in name or "heroic" in name or game.get("appid"))
                ):
                    return False
            exclude_patterns = [
                "launcher",
                "manager",
                "runtime",
                "proton",
                "tool",
                "steamtools",
                "mod manager",
                "nexus mods",
                "vortex",
                "portproton",
                "protonup",
                "goverlay",
                "piper",
                "parsec",
                "moonlight",
                "millennium",
            ]
            if any(p in name for p in exclude_patterns):
                return False
        if game.get("category") in filtering.get("exclude_categories", []):
            return False
        game_name_lower = game.get("name", "").lower()
        if any(
            k.lower() in game_name_lower for k in filtering.get("exclude_keywords", [])
        ):
            return False
        return True

    _SOURCE_PRIORITY = {
        "steam": 4,
        "epic": 3,
        "gog": 3,
        "amazon": 3,
        "heroic": 3,
        "lutris": 2,
        "desktop": 1,
        "manual": 5,
    }

    def _metadata_score(self, game: Dict[str, Any]) -> int:
        return (
            (3 if game.get("image") else 0)
            + (2 if game.get("last_played", 0) > 0 else 0)
            + (1 if game.get("appid") else 0)
            + (1 if game.get("logo") else 0)
        )

    def _deduplicate_games(self, games: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        groups: Dict[str, List[Dict[str, Any]]] = {}
        for game in games:
            groups.setdefault(game.get("name", "").strip().lower(), []).append(game)

        result = []
        for entries in groups.values():
            if len(entries) == 1:
                result.append(entries[0])
                continue
            entries.sort(
                key=lambda g: (
                    self._SOURCE_PRIORITY.get(g.get("source", ""), 0),
                    self._metadata_score(g),
                ),
                reverse=True,
            )
            merged = dict(entries[0])
            for other in entries[1:]:
                for field in ("image", "logo", "last_played", "appid"):
                    if not merged.get(field) and other.get(field):
                        merged[field] = other[field]
            result.append(merged)
        return result

    def merge_games(self) -> List[Dict[str, Any]]:
        steam_games = self.scanner.scan_steam_library()
        steam_shortcuts = self.scanner.scan_steam_shortcuts()
        desktop_games = self.scanner.scan_desktop_files()
        heroic_games = self.scanner.scan_heroic_library()
        lutris_games = self.scanner.scan_lutris_library()
        manual_games = self.load_manual_games()
        config_entries = self.load_config_entries()

        games_dict = {}
        for game in steam_games:
            if self.should_include_game(game):
                games_dict[f"steam:{game['name']}"] = game
        for game in steam_shortcuts:
            if self.should_include_game(game):
                key = f"steam:{game['name']}"
                if key in games_dict:
                    games_dict[key].update(game)
                else:
                    games_dict[key] = game
        for game in heroic_games:
            if self.should_include_game(game):
                games_dict[f"heroic:{game['name']}"] = game
        for game in lutris_games:
            if self.should_include_game(game):
                games_dict[f"lutris:{game['name']}"] = game
        for game in config_entries:
            if self.should_include_game(game):
                games_dict[f"config:{game['name']}"] = game
        for game in desktop_games:
            if self.should_include_game(game):
                key = f"desktop:{game['name']}"
                if key not in games_dict:
                    games_dict[key] = game
        for game in manual_games:
            matched = [k for k in games_dict if k.endswith(f":{game['name']}")]
            if matched:
                for k in matched:
                    games_dict[k].update(game)
            else:
                games_dict[f"manual:{game['name']}"] = game

        games = self._deduplicate_games(list(games_dict.values()))

        sgdb_config = self.config.get("steamgriddb", {})
        if sgdb_config.get("enabled", False) and sgdb_config.get(
            "parallel_requests", True
        ):
            games = self.sgdb.fetch_images_parallel(games)

        favorites = self.load_favorites()
        for game in games:
            key = f"{game.get('name', '')}:{game.get('source', '')}"
            game["favorite"] = key in favorites

        return games

    def sort_games(self, games: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        sort_by = self.config.get("behavior", {}).get("sort_by", "name")
        show_favorites_first = self.config.get("behavior", {}).get(
            "show_favorites_first", True
        )
        if show_favorites_first:
            games.sort(key=lambda g: not g.get("favorite", False))
        if sort_by == "recent":
            games.sort(key=lambda g: g.get("last_played", 0), reverse=True)
        elif sort_by == "playtime":
            games.sort(key=lambda g: g.get("playtime", 0), reverse=True)
        elif sort_by == "name":
            games.sort(key=lambda g: g.get("name", "").lower())
        return games

    def _load_wal_json(self, path: str) -> Dict[str, str]:
        try:
            with open(expand_path(path), "r") as f:
                data = json.load(f)
            colors = {}
            if "special" in data:
                colors.update(data["special"])
            if "colors" in data:
                colors.update(data["colors"])
            return colors
        except Exception:
            return {}

    def load_wallust_colors(self) -> Dict[str, str]:
        return self._load_wal_json(
            self.config.get("appearance", {}).get(
                "wallust_path", "~/.cache/wal/wal.json"
            )
        )

    def load_matugen_colors(self) -> Dict[str, str]:
        return self._load_wal_json(
            self.config.get("appearance", {}).get(
                "matugen_colors_path", "~/.cache/matugen/game_launcher_colors.json"
            )
        )

    def get_all_games(self) -> Dict[str, Any]:
        games = self.sort_games(self.merge_games())
        appearance = self.config.get("appearance", {})
        if appearance.get("use_matugen", False):
            palette = self.load_matugen_colors()
        elif appearance.get("use_wallust", True):
            palette = self.load_wallust_colors()
        else:
            palette = {}
        state = self.load_state()
        return {
            "games": games,
            "config": self.config,
            "colors": palette,
            "last_source": state.get("last_source", ""),
            "last_game": state.get("last_game", ""),
        }

    def output_json(self):
        data = self.get_all_games()
        print(json.dumps(data, indent=2), flush=True)
        self._spawn_image_downloader(data["games"])

    def _spawn_image_downloader(self, games: List[Dict[str, Any]]):
        import subprocess
        import tempfile

        urls = []
        for game in games:
            for field in ("image", "image_animated", "logo"):
                url = game.get(field, "")
                if url and url.startswith("http"):
                    urls.append(url)
            for url in game.get("images", []):
                if url and url.startswith("http"):
                    urls.append(url)
        if not urls:
            return
        tmp = tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False)
        json.dump(urls, tmp)
        tmp.close()
        subprocess.Popen(
            ["python3", str(Path(__file__).absolute()), "download-cache", tmp.name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )

    def download_missing_images(self, urls_file: str):
        self.image_cache.clear_orphaned_images()
        try:
            with open(urls_file) as f:
                urls = json.load(f)
            os.unlink(urls_file)
        except Exception:
            return
        for url in urls:
            local = self.image_cache.cached_image_path(url)
            if Path(local).exists():
                continue
            try:
                request = urllib.request.Request(url)
                request.add_header("User-Agent", "QuickShell-GameLauncher/2.0")
                with urllib.request.urlopen(request, timeout=30) as resp:
                    data = resp.read()
                with open(local, "wb") as f:
                    f.write(data)
            except Exception as e:
                print(f"[downloader] {url}: {e}", file=sys.stderr)


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "toggle":
        name = sys.argv[2]
        source = sys.argv[3] if len(sys.argv) > 3 else ""
        GameLauncher().toggle_favorite(name, source)
    elif len(sys.argv) >= 4 and sys.argv[1] == "save-state":
        GameLauncher().save_state(sys.argv[2], sys.argv[3])
    elif len(sys.argv) >= 3 and sys.argv[1] == "download-cache":
        GameLauncher().download_missing_images(sys.argv[2])
    else:
        GameLauncher().output_json()


if __name__ == "__main__":
    main()
